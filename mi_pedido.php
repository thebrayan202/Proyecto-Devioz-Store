<?php

declare(strict_types=1);

require_once __DIR__ . '/includes/functions.php';

$requestedOrderId = max(0, (int)($_GET['id'] ?? 0));
$orderId = $requestedOrderId > 0 && is_customer()
    ? $requestedOrderId
    : (int) ($_SESSION['customer_order_id'] ?? 0);
if ($orderId <= 0) redirect('pedido_login.php');

$statement = $requestedOrderId > 0
    ? db()->prepare('SELECT * FROM yape_orders WHERE id = ? AND customer_id = ? LIMIT 1')
    : db()->prepare('SELECT * FROM yape_orders WHERE id = ? LIMIT 1');
$statement->execute($requestedOrderId > 0 ? [$orderId, customer_id()] : [$orderId]);
$order = $statement->fetch();
if (!$order) {
    unset($_SESSION['customer_order_id']);
    redirect('pedido_login.php');
}

$itemsStatement = db()->prepare('SELECT item_name, quantity, presentation, units_per_item, unit_price, subtotal FROM yape_order_items WHERE order_id = ? ORDER BY id');
$itemsStatement->execute([$orderId]);
$items = $itemsStatement->fetchAll();

$fulfillment = (string) ($order['fulfillment_status'] ?? 'recibido');
$isExpressOrder = (string) ($order['tipo_despacho'] ?? 'preparacion') === 'entrega_rapida';
$paymentStatus = (string) $order['status'];
$statusLabels = [
    'recibido' => ['Pedido recibido', 'Recibimos tu comprobante y pedido.'],
    'en_preparacion' => ['En preparación', 'Estamos preparando tus productos.'],
    'listo' => ['Pedido listo', 'Tu pedido está listo para ser entregado.'],
    'entregado' => ['Pedido entregado', 'Tu compra fue entregada correctamente.'],
    'cancelado' => ['Pedido cancelado', 'El pedido no continuará.'],
];
if ($paymentStatus === 'pendiente') $current = ['Pago en revisión', 'Estamos verificando el comprobante que enviaste.'];
elseif ($paymentStatus === 'rechazado') $current = ['Pago no aprobado', 'Comunícate con la tienda si necesitas ayuda.'];
else $current = $statusLabels[$fulfillment] ?? $statusLabels['recibido'];

$steps = $isExpressOrder
    ? ['recibido', 'listo', 'entregado']
    : ['recibido', 'en_preparacion', 'listo', 'entregado'];
$currentIndex = array_search($fulfillment, $steps, true);
$currentIndex = $currentIndex === false ? 0 : $currentIndex;

$pageTitle = 'Estado de mi pedido';
require __DIR__ . '/includes/public_header.php';
?>
<section class="order-tracking-section">
    <div class="container order-tracking-shell">
        <header class="order-tracking-head">
            <div><span>SEGUIMIENTO DEL PEDIDO</span><h1><?= e($current[0]) ?></h1><p><?= e($current[1]) ?></p></div>
            <a href="<?= url('pedido_salir.php') ?>">Salir</a>
        </header>

        <?php if ($paymentStatus !== 'rechazado'): ?>
            <div class="order-progress" aria-label="Progreso del pedido">
                <?php foreach ($steps as $index => $step): ?>
                    <article class="<?= $paymentStatus === 'aprobado' && $index <= $currentIndex ? 'is-complete' : ($index === 0 ? 'is-current' : '') ?>">
                        <i><?= $index < $currentIndex && $paymentStatus === 'aprobado' ? '✓' : $index + 1 ?></i>
                        <span><?= e($statusLabels[$step][0]) ?></span>
                    </article>
                <?php endforeach; ?>
            </div>
        <?php endif; ?>

        <div class="order-customer-grid">
            <section class="order-customer-card">
                <div class="order-code-line"><span><?= e($order['order_code']) ?></span><b class="status-chip status-<?= e($paymentStatus) ?>"><?= e(ucfirst($paymentStatus)) ?></b></div>
                <h2>Productos de tu pedido</h2>
                <div class="customer-order-items">
                    <?php foreach ($items as $item): ?>
                        <article><div><strong><?= e($item['item_name']) ?></strong><small><?= (int) $item['quantity'] ?> × <?= money($item['unit_price']) ?><?= $item['presentation'] === 'paquete' ? ' · pack de ' . (int) $item['units_per_item'] : '' ?></small></div><b><?= money($item['subtotal']) ?></b></article>
                    <?php endforeach; ?>
                </div>
                <div class="order-price-breakdown">
                    <span>Subtotal <b><?= money($order['subtotal_amount'] ?? $order['expected_amount']) ?></b></span>
                    <?php if((float)($order['delivery_fee'] ?? 0)>0): ?><span>Delivery <b><?= money($order['delivery_fee']) ?></b></span><?php endif ?>
                    <?php if((float)($order['discount_amount'] ?? 0)>0): ?><span>Descuento<?= !empty($order['coupon_code'])?' · '.e($order['coupon_code']):'' ?> <b>-<?= money($order['discount_amount']) ?></b></span><?php endif ?>
                </div>
                <footer><span>Total pagado</span><strong><?= money($order['expected_amount']) ?></strong></footer>
            </section>
            <aside class="order-customer-summary">
                <span class="order-status-icon"><?= $fulfillment === 'entregado' ? '✓' : '⌛' ?></span>
                <small>ESTADO ACTUAL</small><strong><?= e($current[0]) ?></strong><p><?= e($current[1]) ?></p>
                <dl><div><dt>Pedido</dt><dd><?= e($order['order_code']) ?></dd></div><div><dt>Fecha</dt><dd><?= e(date('d/m/Y H:i', strtotime($order['created_at']))) ?></dd></div><?php if(!empty($order['delivery_address'])): ?><div><dt>Entrega</dt><dd><?= e($order['delivery_address']) ?></dd></div><?php endif ?></dl>
                <em>La página se actualiza automáticamente.</em>
            </aside>
        </div>
        <?php if ($paymentStatus === 'aprobado' && $fulfillment === 'entregado'): ?>
            <?php
                $secureReceiptUrl = receipt_url((int) $order['id']);
                $telegramShareUrl = 'https://t.me/share/url?url=' . rawurlencode($secureReceiptUrl)
                    . '&text=' . rawurlencode('Mi recibo de Devioz Store · ' . receipt_number($order));
            ?>
            <section class="customer-receipt-ready">
                <span class="receipt-ready-icon">✓</span>
                <div><small>RECIBO DISPONIBLE</small><h2><?= e(receipt_number($order)) ?></h2><p>Puedes abrirlo, imprimirlo o compartirlo desde tu celular.</p></div>
                <div class="receipt-ready-actions">
                    <a class="btn btn-primary" href="<?= e($secureReceiptUrl) ?>">Ver recibo</a>
                    <a class="btn btn-secondary" href="<?= e($secureReceiptUrl) ?>" target="_blank" rel="noopener">Guardar / compartir</a>
                    <a class="btn btn-secondary" href="<?= e($telegramShareUrl) ?>" target="_blank" rel="noopener">Enviar por Telegram</a>
                </div>
            </section>
        <?php endif; ?>
    </div>
</section>
<?php if(!in_array($fulfillment,['entregado','cancelado'],true) && $paymentStatus!=='rechazado'): ?><script>window.setInterval(() => {if(!document.hidden)window.location.reload();}, 15000);</script><?php endif ?>
<?php require __DIR__ . '/includes/public_footer.php'; ?>
