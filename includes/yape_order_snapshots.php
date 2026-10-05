<?php

declare(strict_types=1);

require_once __DIR__ . '/ai_recommendations.php';

function yape_require_transaction(PDO $db): void
{
    if (!$db->inTransaction()) {
        throw new LogicException('La operación de reserva debe ejecutarse dentro de una transacción.');
    }
}

/**
 * @return array{rows:list<array<string,mixed>>,sums:array<int,int>}
 */
function yape_lock_active_reservations(PDO $db, int $orderId): array
{
    yape_require_transaction($db);
    $query = $db->prepare(
        "SELECT r.id, r.order_id, r.product_id, r.quantity, r.expires_at,
                p.name, p.category, p.description, p.restricted, p.catalog_scope
         FROM stock_reservations r
         INNER JOIN products p ON p.id = r.product_id
         WHERE r.order_id = ? AND r.status = 'active'
         ORDER BY r.id FOR UPDATE"
    );
    $query->execute([$orderId]);
    $rows = $query->fetchAll();
    if (!$rows) {
        throw new RuntimeException('El pedido no tiene una reserva activa verificable; requiere conciliación manual.');
    }

    $sums = [];
    foreach ($rows as $row) {
        $productId = (int) ($row['product_id'] ?? 0);
        $quantity = (int) ($row['quantity'] ?? 0);
        if ($productId < 1 || $quantity < 1 || ($row['catalog_scope'] ?? '') !== 'master') {
            throw new RuntimeException('El pedido contiene una reserva fuera del catálogo maestro y requiere conciliación manual.');
        }
        $sums[$productId] = ($sums[$productId] ?? 0) + $quantity;
    }
    ksort($sums);

    return ['rows' => $rows, 'sums' => $sums];
}

/** @param list<array<string,mixed>> $reservationRows */
function yape_snapshot_has_restricted_product(array $reservationRows): bool
{
    foreach ($reservationRows as $row) {
        if ((int) ($row['restricted'] ?? 0) === 1 || is_age_restricted_product($row)) {
            return true;
        }
    }
    return false;
}

/**
 * Locks the original Yape movements and verifies that they still describe the
 * same per-product physical reservation. Version 2 additionally verifies the
 * immutable combo-component graph written at checkout.
 *
 * @param array<string,mixed> $order
 * @param list<array<string,mixed>> $items
 * @param array{rows:list<array<string,mixed>>,sums:array<int,int>} $reservationSnapshot
 * @return list<array<string,mixed>>
 */
function yape_assert_snapshot_coherence(PDO $db, array $order, array $items, array $reservationSnapshot): array
{
    yape_require_transaction($db);
    $paymentMethod = (string) ($order['metodo_pago'] ?? 'yape');
    if (!in_array($paymentMethod, ['yape', 'plin'], true)) {
        throw new RuntimeException('El pedido no corresponde a un pago digital pendiente de revisión.');
    }
    $version = (int) ($order['inventory_snapshot_version'] ?? 0);
    if ($version < 1 || $version > 2) {
        throw new RuntimeException('Pedido legacy sin una reserva verificable; requiere conciliación manual y no se modificó el stock.');
    }
    if (!$items) {
        throw new RuntimeException('El pedido no contiene líneas de venta verificables.');
    }
    foreach ($items as $item) {
        if ($item['stock_after'] === null
            || (int) ($item['item_id'] ?? 0) < 1
            || (int) ($item['quantity'] ?? 0) < 1
            || !in_array($item['item_type'] ?? '', ['product', 'combo'], true)) {
            throw new RuntimeException('El pedido tiene una reserva incompleta y requiere conciliación manual.');
        }
    }

    $movementQuery = $db->prepare(
        "SELECT id, product_id, units_changed
         FROM inventory_movements
         WHERE reference = ? AND payment_method = ?
         ORDER BY id FOR UPDATE"
    );
    $movementQuery->execute([(string) ($order['order_code'] ?? ''), $paymentMethod]);
    $movementSums = [];
    foreach ($movementQuery->fetchAll() as $movement) {
        $productId = (int) ($movement['product_id'] ?? 0);
        $units = (int) ($movement['units_changed'] ?? 0);
        if ($productId < 1 || $units < 1) {
            throw new RuntimeException('Los movimientos históricos del pedido no son verificables.');
        }
        $movementSums[$productId] = ($movementSums[$productId] ?? 0) + $units;
    }
    $reservationSums = $reservationSnapshot['sums'];
    ksort($movementSums);
    ksort($reservationSums);
    if ($movementSums !== $reservationSums) {
        throw new RuntimeException('La reserva y los movimientos históricos no coinciden; no se modificó el stock.');
    }

    if ($version === 1) {
        return [];
    }

    $componentQuery = $db->prepare(
        "SELECT c.*, i.item_type, i.quantity AS line_quantity, i.subtotal AS line_subtotal,
                i.unit_cost AS line_unit_cost, i.profit AS line_profit
         FROM yape_order_item_components c
         INNER JOIN yape_order_items i ON i.id = c.order_item_id
         WHERE i.order_id = ?
         ORDER BY c.order_item_id, c.id FOR UPDATE"
    );
    $componentQuery->execute([(int) $order['id']]);
    $components = $componentQuery->fetchAll();
    $componentsByItem = [];
    foreach ($components as $component) {
        $componentsByItem[(int) $component['order_item_id']][] = $component;
    }

    $snapshotSums = [];
    foreach ($items as $item) {
        $itemId = (int) $item['id'];
        $quantity = (int) $item['quantity'];
        if ($item['item_type'] === 'product') {
            if (isset($componentsByItem[$itemId]) || (int) ($item['manual_combo_stock_reserved'] ?? 0) !== 0) {
                throw new RuntimeException('La instantánea de producto del pedido no es coherente.');
            }
            $productId = (int) $item['item_id'];
            $units = $quantity * max(1, (int) $item['units_per_item']);
            $snapshotSums[$productId] = ($snapshotSums[$productId] ?? 0) + $units;
            continue;
        }

        if ($item['manual_combo_stock_reserved'] === null || empty($componentsByItem[$itemId])) {
            throw new RuntimeException('La instantánea de componentes del combo está incompleta.');
        }
        $allocatedIncome = 0.0;
        $totalCost = 0.0;
        $totalProfit = 0.0;
        foreach ($componentsByItem[$itemId] as $component) {
            $unitsPerCombo = (int) ($component['units_per_combo'] ?? 0);
            $reservedUnits = (int) ($component['reserved_units'] ?? 0);
            if ($unitsPerCombo < 1 || $reservedUnits !== $quantity * $unitsPerCombo) {
                throw new RuntimeException('La cantidad histórica de un componente no coincide con el combo reservado.');
            }
            $productId = (int) $component['product_id'];
            $snapshotSums[$productId] = ($snapshotSums[$productId] ?? 0) + $reservedUnits;
            $allocatedIncome += (float) $component['allocated_income'];
            $totalCost += (float) $component['total_cost'];
            $totalProfit += (float) $component['profit'];
        }
        if (abs(round($allocatedIncome, 2) - (float) $item['subtotal']) > 0.005
            || abs(round($totalCost, 2) - round((float) $item['unit_cost'] * $quantity, 2)) > 0.005
            || abs(round($totalProfit, 2) - (float) $item['profit']) > 0.005) {
            throw new RuntimeException('La asignación financiera histórica del combo no es coherente.');
        }
    }
    ksort($snapshotSums);
    if ($snapshotSums !== $reservationSums) {
        throw new RuntimeException('La instantánea de componentes no coincide con la reserva física.');
    }

    return $components;
}

/** @param list<array<string,mixed>> $reservationRows */
function yape_mark_reservation_rows(PDO $db, array $reservationRows, string $status): void
{
    yape_require_transaction($db);
    if (!$reservationRows || !in_array($status, ['converted', 'released', 'expired'], true)) {
        throw new InvalidArgumentException('Estado o filas de reserva inválidos.');
    }
    $ids = array_map(static fn (array $row): int => (int) $row['id'], $reservationRows);
    $placeholders = implode(',', array_fill(0, count($ids), '?'));
    $update = $db->prepare("UPDATE stock_reservations SET status = ? WHERE id IN ($placeholders) AND status = 'active'");
    $update->execute(array_merge([$status], $ids));
    if ($update->rowCount() !== count($ids)) {
        throw new RuntimeException('La reserva cambió mientras se procesaba; no se aplicó ningún cambio.');
    }
}

/** @param list<array<string,mixed>> $reservationRows */
function yape_convert_reservations(PDO $db, array $reservationRows): void
{
    yape_mark_reservation_rows($db, $reservationRows, 'converted');
}

/**
 * @param array{rows:list<array<string,mixed>>,sums:array<int,int>} $reservationSnapshot
 */
function yape_release_reservations(PDO $db, array $reservationSnapshot, string $status): void
{
    if (!in_array($status, ['released', 'expired'], true)) {
        throw new InvalidArgumentException('Estado de liberación inválido.');
    }
    yape_mark_reservation_rows($db, $reservationSnapshot['rows'], $status);
    $restore = $db->prepare("UPDATE products SET stock = stock + ? WHERE id = ? AND catalog_scope = 'master'");
    foreach ($reservationSnapshot['sums'] as $productId => $quantity) {
        $restore->execute([$quantity, $productId]);
        if ($restore->rowCount() !== 1) {
            throw new RuntimeException('No se pudo restaurar un producto maestro reservado.');
        }
    }
}

/**
 * Restores only manual combo caps explicitly recorded by version 2. A legacy
 * NULL is never guessed from the current combo definition.
 *
 * @param list<array<string,mixed>> $items
 * @return list<string>
 */
function yape_release_manual_combo_caps(PDO $db, array $items, int $snapshotVersion): array
{
    yape_require_transaction($db);
    $caps = [];
    $warnings = [];
    foreach ($items as $item) {
        if (($item['item_type'] ?? '') !== 'combo') {
            continue;
        }
        $flag = $item['manual_combo_stock_reserved'] ?? null;
        if ($flag === null) {
            if ($snapshotVersion === 1) {
                $warnings[] = 'El límite manual de un combo legacy requiere conciliación.';
                continue;
            }
            throw new RuntimeException('La instantánea del límite manual del combo está incompleta.');
        }
        if ((int) $flag !== 1) {
            continue;
        }
        $comboId = (int) $item['item_id'];
        $caps[$comboId] = ($caps[$comboId] ?? 0) + (int) $item['quantity'];
    }

    $lock = $db->prepare('SELECT id, stock FROM combos WHERE id = ? FOR UPDATE');
    $restore = $db->prepare('UPDATE combos SET stock = stock + ? WHERE id = ? AND stock IS NOT NULL');
    foreach ($caps as $comboId => $quantity) {
        $lock->execute([$comboId]);
        $combo = $lock->fetch();
        if (!$combo || $combo['stock'] === null) {
            $warnings[] = 'El combo #' . $comboId . ' ya no usa un límite manual; no se alteró su configuración actual.';
            continue;
        }
        $restore->execute([$quantity, $comboId]);
        if ($restore->rowCount() !== 1) {
            throw new RuntimeException('No se pudo restaurar el límite manual del combo reservado.');
        }
    }
    return array_values(array_unique($warnings));
}

function yape_delete_provisional_movements(PDO $db, string $orderCode, string $paymentMethod): void
{
    yape_require_transaction($db);
    if (!in_array($paymentMethod, ['yape', 'plin'], true)) {
        throw new InvalidArgumentException('El método de pago no corresponde a una reserva provisional.');
    }
    $delete = $db->prepare('DELETE FROM inventory_movements WHERE reference = ? AND payment_method = ?');
    $delete->execute([$orderCode, $paymentMethod]);
}
