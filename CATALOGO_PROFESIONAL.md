# Devioz Store profesional

## Antes de instalar

Haz una copia de seguridad desde phpMyAdmin. La actualización no elimina productos, pedidos, usuarios, movimientos ni configuraciones existentes.

## Instalación nueva en XAMPP para macOS

1. Copia `stockflow` dentro de `/Applications/XAMPP/xamppfiles/htdocs/`.
2. Activa Apache y MySQL.
3. Ejecuta `INSTALAR_REPARACION_DB.command`.
4. Abre `http://localhost/stockflow/`.

El instalador crea `devioz_shop_reparada`, carga la base completa y después aplica `database/upgrade_catalogo_unificado_profesional.sql`.

## Actualizar una instalación existente

1. Selecciona tu base actual en phpMyAdmin.
2. Importa `database/upgrade_catalogo_unificado_profesional.sql`.
3. No cambies `config/database.php` si el proyecto ya conectaba correctamente.

La migración puede volver a importarse: conserva los datos y mantiene el margen global existente. El margen externo inicial es 25 %.

## Rutas nuevas

- Administración unificada: `http://localhost/stockflow/admin/todos_productos.php`
- Rentabilidad: `http://localhost/stockflow/admin/precios.php`
- Contenido de portada: `http://localhost/stockflow/admin/contenido_tienda.php`
- Tienda pública: `http://localhost/stockflow/`

## Ollama local

La configuración predeterminada busca Ollama en `http://127.0.0.1:11434` y el modelo `llama3.2:3b`. Puedes cambiar el modelo con la variable `SHOPPING_AI_MODEL`. Si Ollama o el modelo no están disponibles, la tienda continúa con recomendaciones por reglas y nunca inventa productos, precios o stock.

El asistente excluye productos restringidos por edad y requiere confirmación antes de agregar la propuesta al carrito.

## Reversión

Si necesitas volver al estado anterior, restaura la copia de seguridad creada antes de actualizar y reemplaza la carpeta por tu copia anterior. No borres tablas manualmente si contienen información de producción.

## Verificación en XAMPP

Desde Terminal, dentro de la carpeta del proyecto:

```bash
for test in tests/*_test.php; do /Applications/XAMPP/xamppfiles/bin/php "$test" || exit 1; done
find . -name '*.php' -not -path './vendor/*' -print0 | xargs -0 -n1 /Applications/XAMPP/xamppfiles/bin/php -l
```
