<?php if(!isset($order,$business,$items)){http_response_code(404);exit;} ?>
<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="robots" content="noindex,nofollow"><meta name="referrer" content="no-referrer">
<title><?= e($number) ?> · <?= e($business['name']) ?></title>
<link rel="stylesheet" href="<?= e(url('assets/css/receipt.css')) ?>">
</head>
<body class="ticket-page">
<main class="ticket-shell">
<div class="ticket-screen-heading"><span>✓ Compra entregada</span><p>Tu recibo, listo para guardar</p></div>
<article class="ticket" id="receiptTicket">
<header class="ticket-brand"><h1><?= e($business['name']) ?></h1><p><?= e($business['tagline']) ?></p>
<?php foreach(['legal_name','address','phone','website'] as $key): ?>
<?php if($business[$key]!==''): ?><p><?= e($business[$key]) ?></p><?php endif ?>
<?php endforeach ?>
<?php if($business['ruc']!==''): ?><p>RUC: <?= e($business['ruc']) ?></p><?php endif ?>
</header>
<div class="ticket-section ticket-center"><h2>COMPROBANTE DE ENTREGA</h2><strong><?= e($number) ?></strong><p><?= e(date('d/m/Y H:i',strtotime($order['delivered_at']?:$order['created_at']))) ?> · Lima</p><p>Pedido: <?= e($order['order_code']) ?></p></div>
<table class="ticket-items"><thead><tr><th scope="col">Cant. / descripción</th><th scope="col">Importe</th></tr></thead><tbody>
<?php foreach($items as $item): ?>
<tr><td><strong><?= (int)$item['quantity'] ?> × <?= e($item['item_name']) ?></strong><small><?= money($item['unit_price']) ?> c/u<?= $item['presentation']==='paquete'?' · Pack de '.(int)$item['units_per_item']:'' ?></small></td><td><?= money($item['subtotal']) ?></td></tr>
<?php endforeach ?>
</tbody></table>
<dl class="ticket-totals"><div class="ticket-grand"><dt>TOTAL</dt><dd><?= money($order['expected_amount']) ?></dd></div>
<div><dt>Medio de pago</dt><dd><?= e(payment_label($paymentMethod)) ?></dd></div>
<?php if($paymentMethod==='efectivo'): ?>
<div><dt>Recibido</dt><dd><?= isset($order['monto_paga_con'])?money($order['monto_paga_con']):'No registrado' ?></dd></div>
<div><dt>Vuelto</dt><dd><?= isset($order['vuelto'])?money($order['vuelto']):'No registrado' ?></dd></div>
<?php endif ?>
<div><dt>Presentaciones vendidas</dt><dd><?= array_sum(array_column($items,'quantity')) ?></dd></div>
</dl>
<div class="ticket-code"><?= receipt_barcode($number) ?><p><?= e($number) ?></p><small>Código interno del recibo</small></div>
<footer class="ticket-center ticket-section"><strong>¡Gracias por tu compra!</strong><p>Documento interno.<br>No es boleta ni factura electrónica.</p><small>Conserva este recibo para consultar tu compra.</small></footer>
</article>
<section class="ticket-controls" aria-label="Opciones del recibo">
<label for="paperWidth">Formato de impresión</label><select id="paperWidth"><option value="80">Ticket de 80 mm</option><option value="58">Ticket de 58 mm</option><option value="a4">Hoja A4 / PDF</option></select>
<button type="button" id="printReceipt">Imprimir / guardar PDF</button>
<button type="button" id="shareReceipt">Compartir recibo</button>
<a href="<?= e($receiptLink.'&download=txt') ?>" download>Descargar texto</a>
<button type="button" id="copyReceipt">Copiar enlace</button>
<p id="receiptFeedback" role="status" aria-live="polite"></p>
<div id="receiptLinkFallback" hidden><label for="receiptLink">Mantén pulsado el enlace para copiarlo</label><input id="receiptLink" readonly value="<?= e($receiptLink) ?>"></div>
<small>En celular, usa las opciones de impresión o compartir del navegador para guardar PDF. El enlace permite ver este recibo; compártelo solo con quien corresponda.</small>
<a href="<?= e(url('index.php')) ?>">Volver a la tienda</a>
</section>
</main>
<script type="application/json" id="receiptData"><?= json_encode(['url'=>$receiptLink,'title'=>$business['name'].' · '.$number,'autoPrint'=>$autoPrint],JSON_HEX_TAG|JSON_HEX_AMP|JSON_HEX_APOS|JSON_HEX_QUOT) ?></script>
<script src="<?= e(url('assets/js/receipt.js')) ?>" defer></script>
</body></html>
