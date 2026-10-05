# Recibo digital de pedidos

## Flujo

1. El administrador procesa el pedido normalmente.
2. Al pulsar **Confirmar entrega**, StockFlow habilita el recibo digital.
3. Telegram envía automáticamente al administrador el resumen y el enlace seguro del recibo.
4. El cliente encuentra en **Mi pedido** los botones para verlo, guardarlo como PDF, imprimirlo o compartirlo por Telegram.

## Cliente sin Telegram

No necesita registrar teléfono ni correo. Puede ingresar con el código y PIN del pedido y descargar el recibo desde la página de seguimiento.

## Seguridad

Los enlaces compartidos incluyen una firma aleatoria HMAC. El recibo solo se habilita si el pago está aprobado y el pedido figura como entregado.

En producción configura `APP_BASE_URL` con la dirección pública completa de la tienda para que los enlaces recibidos por Telegram abran correctamente. Ejemplo: `https://tudominio.com/stockflow`.

## Importante

Es un comprobante interno de compra. No reemplaza una boleta o factura electrónica autorizada por SUNAT.
