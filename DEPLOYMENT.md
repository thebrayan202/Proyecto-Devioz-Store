# Publicación de Devioz Store

## Requisitos mínimos

- PHP 8.0 o superior con PDO MySQL, Fileinfo, Mbstring y cURL recomendado para Telegram.
- MySQL 5.7+ o MariaDB 10.4+.
- HTTPS activo.
- Apache con `mod_headers`, `mod_deflate` y `mod_expires` recomendados.

## Variables del servidor

Configura estas variables desde el panel del hosting; no guardes contraseñas dentro del proyecto:

```text
APP_ENV=production
APP_DEBUG=0
APP_BASE_URL=https://tudominio.com
DB_HOST=servidor_mysql
DB_PORT=3306
DB_NAME=devioz_shop
DB_USER=usuario_privado
DB_PASS=contraseña_segura
```

## Despliegue seguro

1. Exporta una copia de la base de datos actual.
2. Conserva una copia completa de `assets/uploads/`.
3. Sube los archivos nuevos sin borrar `assets/uploads/` del servidor.
4. En una instalación nueva, importa `database/devioz_shop_integrada.sql`. Si `devioz_shop` ya existe, importa `database/stockflow.sql` y luego `database/integrar_catalogo_devioz.sql`.
5. Antes de iniciar sesión como administrador, ejecuta `CREAR_ADMIN_INICIAL.command` desde Terminal/XAMPP. Define una contraseña fuerte cuando el asistente la solicite; no existe una contraseña predeterminada. Si usas un nombre de base distinto de `devioz_shop_reparada`, escríbelo exactamente en la confirmación adicional.
6. Comprueba permisos de escritura en `assets/uploads/` (`755` para carpetas suele ser suficiente).
7. Activa HTTPS y redirección permanente desde el panel del hosting.
8. Prueba: catálogo, búsqueda, galería, combo, carrito, carga de comprobante y aprobación Yape.
9. Configura Telegram desde **Centro de pagos**, registra un pedido de prueba, márcalo como entregado y verifica el enlace del recibo.

### Actualización desde una versión anterior

Si ya tienes productos y ventas guardados, importa únicamente `database/upgrade_tracking_pedidos.sql`. Esta migración agrega el PIN seguro y los estados de preparación/entrega sin borrar información existente. Los pedidos creados después de la actualización recibirán su código y PIN automáticamente.

## Regla importante sobre imágenes

Las imágenes cargadas son datos del negocio. Al actualizar la aplicación no reemplaces la carpeta `assets/uploads/` por una carpeta vacía. Si el servidor no permite escribir allí, StockFlow utiliza automáticamente `uploaded_media` en MySQL.

## Copias de seguridad

Programa un respaldo diario de MySQL y semanal de `assets/uploads/`. Conserva al menos siete copias diarias y cuatro semanales.
