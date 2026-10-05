# Notificaciones de pedidos por Telegram

## Configuración

1. En Telegram abre el bot oficial `@BotFather`.
2. Usa `/newbot`, asigna un nombre y copia el token entregado.
3. Abre una conversación con tu bot y envíale cualquier mensaje.
4. Obtén el Chat ID consultando `https://api.telegram.org/botTU_TOKEN/getUpdates` en el navegador. El número aparece dentro de `chat.id`.
5. En StockFlow entra a **Administración → Centro de pagos → Notificaciones por Telegram**.
6. Escribe el token y el Chat ID, activa Telegram y pulsa **Guardar y enviar prueba**.

No necesitas modificar tablas manualmente porque `store_settings` admite estas claves. Si deseas precargarlas en una instalación existente, importa una sola vez `database/upgrade_telegram_notifications.sql`.

## Funcionamiento

- Se envía un aviso al registrarse cualquier pedido de Yape o efectivo.
- El aviso incluye código, productos, total, método de pago, vuelto y tipo de despacho.
- Los pedidos se guardan antes de intentar el envío. Si Telegram no responde, la venta y el stock permanecen registrados.
- El token se conserva en la configuración de la tienda y no vuelve a mostrarse en el formulario.

## Requisito del servidor

PHP debe tener habilitado cURL o `allow_url_fopen`, además de acceso HTTPS a `api.telegram.org`.
