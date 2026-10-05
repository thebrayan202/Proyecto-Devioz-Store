<?php
declare(strict_types=1);
require_once __DIR__ . '/../includes/functions.php';
require_once __DIR__ . '/../includes/ai_recommendations.php';
require_once __DIR__ . '/../includes/yape_order_snapshots.php';
require_admin();

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    verify_csrf();
    $id = max(0, (int) ($_POST['id'] ?? 0));
    $action = (string) ($_POST['action'] ?? 'payment');
    if ($action === 'fulfillment' && $id > 0) {
        try {
            $query = db()->prepare('SELECT status, fulfillment_status, tipo_despacho FROM yape_orders WHERE id = ? LIMIT 1');
            $query->execute([$id]);
            $order = $query->fetch();
            if (!$order || $order['status'] !== 'aprobado') throw new RuntimeException('Primero debes aprobar el pago del pedido.');
            $current = (string) ($order['fulfillment_status'] ?? 'recibido');
            $next = (string) ($_POST['fulfillment_status'] ?? '');
            $isExpress = (string) ($order['tipo_despacho'] ?? 'preparacion') === 'entrega_rapida';
            $allowedTransitions = $isExpress
                ? [
                    'recibido' => ['entregado'],
                    'en_preparacion' => ['entregado'],
                    'listo' => ['entregado'],
                    'entregado' => [],
                    'cancelado' => [],
                ]
                : [
                    'recibido' => ['en_preparacion'],
                    'en_preparacion' => ['listo'],
                    'listo' => ['entregado'],
                    'entregado' => [],
                    'cancelado' => [],
                ];
            if (!in_array($next, $allowedTransitions[$current] ?? [], true)) throw new RuntimeException('El cambio de estado no es válido.');
            db()->prepare("UPDATE yape_orders SET fulfillment_status = ?, status_updated_at = NOW(), delivered_at = CASE WHEN ? = 'entregado' THEN NOW() ELSE delivered_at END WHERE id = ?")
                ->execute([$next, $next, $id]);
            $labels = ['en_preparacion' => 'Pedido enviado a preparación.', 'listo' => 'Pedido marcado como listo.', 'entregado' => 'Pedido marcado como entregado.'];
            $message = $labels[$next] ?? 'Estado del pedido actualizado.';
            if ($next === 'entregado') {
                try {
                    $telegramReceipt = send_telegram_delivered_notification($id);
                    $message .= $telegramReceipt['success']
                        ? ' El recibo fue enviado al Telegram administrativo.'
                        : ' El recibo está disponible, pero Telegram no pudo enviarlo: ' . $telegramReceipt['message'];
                } catch (Throwable) {
                    $message .= ' El recibo está disponible, pero Telegram no pudo enviar el aviso.';
                }
            }
            flash('success', $message);
        } catch (RuntimeException $exception) { flash('danger', $exception->getMessage()); }
        redirect('admin/pedidos_yape.php');
    }

    $status = (string) ($_POST['status'] ?? '');
    if ($id > 0 && in_array($status, ['aprobado', 'rechazado'], true)) {
        $connection = db();
        $connection->beginTransaction();
        try {
            $orderQuery = $connection->prepare('SELECT * FROM yape_orders WHERE id = ? FOR UPDATE');
            $orderQuery->execute([$id]);
            $order = $orderQuery->fetch();
            if (!$order || $order['status'] !== 'pendiente') throw new RuntimeException('El pedido ya había sido revisado.');
            if (!payment_requires_review((string) ($order['metodo_pago'] ?? ''))) throw new RuntimeException('Este método de pago no requiere revisión de comprobante.');
            $itemsQuery = $connection->prepare('SELECT * FROM yape_order_items WHERE order_id = ? ORDER BY id FOR UPDATE');
            $itemsQuery->execute([$id]);
            $items = $itemsQuery->fetchAll();
            if (!$items) throw new RuntimeException('El pedido no contiene productos para revisar.');
            $reservationSnapshot = yape_lock_active_reservations($connection, $id);
            yape_assert_snapshot_coherence($connection, $order, $items, $reservationSnapshot);

            $effectiveStatus = $status;
            $restricted = false;
            if ($status === 'aprobado') {
                $restricted = yape_snapshot_has_restricted_product($reservationSnapshot['rows']);
                if ($restricted) {
                    yape_release_reservations($connection, $reservationSnapshot, 'released');
                    yape_release_manual_combo_caps($connection, $items, (int) $order['inventory_snapshot_version']);
                    yape_delete_provisional_movements($connection, (string) $order['order_code'], (string) $order['metodo_pago']);
                    $effectiveStatus = 'rechazado';
                }
                if (!$restricted) {
                    yape_convert_reservations($connection, $reservationSnapshot['rows']);
                }
            } elseif ($status === 'rechazado') {
                yape_release_reservations($connection, $reservationSnapshot, 'released');
                yape_release_manual_combo_caps($connection, $items, (int) $order['inventory_snapshot_version']);
                yape_delete_provisional_movements($connection, (string) $order['order_code'], (string) $order['metodo_pago']);
            }

            $fulfillmentStatus = $effectiveStatus === 'aprobado'
                ? (((string) ($order['tipo_despacho'] ?? 'preparacion') === 'entrega_rapida') ? 'listo' : 'recibido')
                : 'cancelado';
            $update = $connection->prepare("UPDATE yape_orders SET status = ?, fulfillment_status = ?, reviewed_at = NOW(), status_updated_at = NOW() WHERE id = ? AND status = 'pendiente'");
            $update->execute([$effectiveStatus, $fulfillmentStatus, $id]);
            if ($update->rowCount() !== 1) throw new RuntimeException('El pedido ya había sido revisado.');
            if ($effectiveStatus === 'aprobado' && !empty($order['coupon_id']) && (float) ($order['discount_amount'] ?? 0) > 0) {
                $couponUsage = $connection->prepare('INSERT IGNORE INTO coupon_usage(coupon_id,customer_id,order_id,discount_amount) VALUES(?,?,?,?)');
                $couponUsage->execute([(int) $order['coupon_id'], $order['customer_id'] ?: null, $id, (float) $order['discount_amount']]);
                if ($couponUsage->rowCount() === 1) $connection->prepare('UPDATE coupons SET used_count=used_count+1 WHERE id=?')->execute([(int) $order['coupon_id']]);
            }
            $connection->commit();
            flash($effectiveStatus === 'aprobado' ? 'success' : 'danger', $effectiveStatus === 'aprobado'
                ? 'Pago aprobado. Se conservaron los importes y movimientos del pedido.'
                : ($restricted ? 'El pedido se rechazó porque el producto reservado quedó restringido; requiere seguimiento del pago.' : 'Pedido rechazado y stock restaurado.'));
        } catch (Throwable $exception) {
            if ($connection->inTransaction()) $connection->rollBack();
            flash('danger', $exception instanceof RuntimeException ? $exception->getMessage() : 'No se pudo actualizar el pedido.');
        }
    }
    redirect('admin/pedidos_yape.php');
}

$filter = (string) ($_GET['status'] ?? '');
$search = trim((string) ($_GET['q'] ?? ''));
$conditions = [];
$parameters = [];
if (in_array($filter, ['pendiente', 'aprobado', 'rechazado'], true)) { $conditions[] = 'o.status = ?'; $parameters[] = $filter; }
if ($search !== '') { $conditions[] = '(o.order_code LIKE ? OR o.operation_code LIKE ? OR i.item_name LIKE ?)'; $like = '%' . $search . '%'; array_push($parameters, $like, $like, $like); }
$where = $conditions ? 'WHERE ' . implode(' AND ', $conditions) : '';
$statement = db()->prepare('SELECT o.*, GROUP_CONCAT(CONCAT(i.quantity, "× ", i.item_name) ORDER BY i.id SEPARATOR " · ") AS items FROM yape_orders o LEFT JOIN yape_order_items i ON i.order_id = o.id ' . $where . ' GROUP BY o.id ORDER BY o.created_at DESC LIMIT 200');
$statement->execute($parameters);
$orders = $statement->fetchAll();
$orderItems = [];
if ($orders) {
    $ids = array_map(static fn (array $order): int => (int) $order['id'], $orders);
    $placeholders = implode(',', array_fill(0, count($ids), '?'));
    $itemsStatement = db()->prepare('SELECT * FROM yape_order_items WHERE order_id IN (' . $placeholders . ') ORDER BY order_id, id');
    $itemsStatement->execute($ids);
    foreach ($itemsStatement->fetchAll() as $item) $orderItems[(int) $item['order_id']][] = $item;
}
$pageTitle = 'Pedidos y comprobantes';
$pageSubtitle = 'Verifica pagos conservando las instantáneas de checkout';
$activePage = 'yape-orders';
$fulfillmentLabels = [
    'recibido' => 'Pedido recibido',
    'en_preparacion' => 'En preparación',
    'listo' => 'Listo para entregar',
    'entregado' => 'Entregado',
    'cancelado' => 'Cancelado',
];
$fulfillmentNext = [
    'recibido' => ['status' => 'en_preparacion', 'label' => 'Iniciar preparación'],
    'en_preparacion' => ['status' => 'listo', 'label' => 'Marcar como listo'],
    'listo' => ['status' => 'entregado', 'label' => 'Confirmar entrega'],
];
require __DIR__ . '/../includes/admin_header.php';
?>
<section class="panel yape-orders-panel">
    <div class="panel-heading"><div><h2>Comprobantes y ventas</h2><p>Los importes, packs y movimientos son los registrados al crear cada pedido.</p></div></div>
    <div class="yape-order-grid">
        <?php foreach ($orders as $order): ?>
            <?php $details = $orderItems[(int) $order['id']] ?? []; ?>
            <article class="yape-order-card status-<?= e($order['status']) ?>"><div class="yape-order-info">
                <div class="yape-order-top"><span><?= e($order['order_code']) ?></span><em><?= e(ucfirst($order['status'])) ?></em></div>
                <h3>Pedido online <small>#<?= (int) $order['id'] ?></small></h3><p><?= e($order['items'] ?: 'Sin detalle') ?></p>
                <dl><div><dt>Cliente</dt><dd><?= e($order['customer_name']) ?> · <?= e($order['customer_phone'] ?? '') ?></dd></div><div><dt>Subtotal</dt><dd><?= money($order['subtotal_amount'] ?? $order['expected_amount']) ?></dd></div><div><dt>Total</dt><dd><?= money($order['expected_amount']) ?></dd></div></dl>
                <section class="yape-financial-detail"><h4>Productos y movimientos del pedido</h4><?php foreach ($details as $item): ?><div class="yape-history-row"><div><strong><?= e($item['item_name']) ?></strong><small><?= (int) $item['quantity'] ?> × <?= money($item['unit_price']) ?><?= ($item['presentation'] ?? 'unidad') === 'paquete' ? ' · Pack de ' . (int) ($item['units_per_item'] ?? 1) : '' ?></small></div><span>Stock <?= (int) $item['stock_before'] ?> → <?= $item['stock_after'] === null ? 'liberado' : (int) $item['stock_after'] ?></span><b><?= money($item['subtotal']) ?></b></div><?php endforeach; ?></section>
                <?php if ($order['status'] === 'aprobado'): ?>
                    <?php
                        $deliveryStatus = (string) ($order['fulfillment_status'] ?? 'recibido');
                        $isExpressOrder = (string) ($order['tipo_despacho'] ?? 'preparacion') === 'entrega_rapida';
                        $nextDelivery = $isExpressOrder
                            ? ($deliveryStatus === 'entregado' ? null : ['status' => 'entregado', 'label' => 'Confirmar entrega'])
                            : ($fulfillmentNext[$deliveryStatus] ?? null);
                    ?>
                    <section class="admin-fulfillment-box">
                        <div class="admin-fulfillment-title"><div><small><?= $isExpressOrder ? 'ENTREGA RÁPIDA' : 'ENTREGA DEL PEDIDO' ?></small><strong><?= e($fulfillmentLabels[$deliveryStatus] ?? 'Pedido recibido') ?></strong></div><span class="fulfillment-pill fulfillment-<?= e($deliveryStatus) ?>"><?= e($fulfillmentLabels[$deliveryStatus] ?? $deliveryStatus) ?></span></div>
                        <?php if ($isExpressOrder): ?>
                            <div class="admin-fulfillment-progress"><span class="is-active"><i>1</i>Listo para entregar</span><span class="<?= $deliveryStatus === 'entregado' ? 'is-active' : '' ?>"><i><?= $deliveryStatus === 'entregado' ? '✓' : '2' ?></i>Entregado</span></div>
                            <?php if ($deliveryStatus !== 'entregado'): ?><p>Entrega rápida: se omite la preparación. Confirma la entrega cuando el cliente reciba el pedido.</p><?php endif; ?>
                        <?php else: ?>
                            <div class="admin-fulfillment-progress">
                                <?php $deliverySteps = ['recibido', 'en_preparacion', 'listo', 'entregado']; $deliveryIndex = array_search($deliveryStatus, $deliverySteps, true); ?>
                                <?php foreach ($deliverySteps as $stepIndex => $step): ?><span class="<?= $deliveryIndex !== false && $stepIndex <= $deliveryIndex ? 'is-active' : '' ?>"><i><?= $stepIndex < (int) $deliveryIndex ? '✓' : $stepIndex + 1 ?></i><?= e($fulfillmentLabels[$step]) ?></span><?php endforeach; ?>
                            </div>
                        <?php endif; ?>
                        <?php if ($nextDelivery): ?>
                            <form method="post" data-confirm="Actualizarás el estado visible para el cliente. ¿Deseas continuar?"><?= csrf_field() ?><input type="hidden" name="action" value="fulfillment"><input type="hidden" name="id" value="<?= (int) $order['id'] ?>"><input type="hidden" name="fulfillment_status" value="<?= e($nextDelivery['status']) ?>"><button class="btn btn-primary" type="submit"><?= e($nextDelivery['label']) ?> <span>→</span></button></form>
                        <?php else: ?>
                            <p>El flujo de entrega de este pedido finalizó.</p><a class="btn btn-secondary" href="<?= e(url('recibo.php?id=' . (int) $order['id'])) ?>" target="_blank" rel="noopener">Ver recibo digital</a>
                        <?php endif; ?>
                    </section>
                <?php endif; ?>
                <?php if ($order['status'] === 'pendiente'): ?><div class="yape-review-actions"><form method="post"><?= csrf_field() ?><input type="hidden" name="id" value="<?= (int) $order['id'] ?>"><input type="hidden" name="status" value="rechazado"><button class="btn btn-secondary" type="submit">Rechazar</button></form><form method="post"><?= csrf_field() ?><input type="hidden" name="id" value="<?= (int) $order['id'] ?>"><input type="hidden" name="status" value="aprobado"><button class="btn btn-primary" type="submit">Aprobar pago</button></form></div><?php endif; ?>
            </div></article>
        <?php endforeach; ?>
        <?php if (!$orders): ?><div class="empty-state"><h3>No hay pedidos en este estado</h3></div><?php endif; ?>
    </div>
</section>
<?php require __DIR__ . '/../includes/admin_footer.php'; ?>
