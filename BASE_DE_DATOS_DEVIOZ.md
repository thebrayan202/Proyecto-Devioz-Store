# Base de datos del catálogo maestro 11,604

La base predeterminada es `devioz_shop_reparada`. El catálogo fuente permanece en `productos`; la operación administrativa y pública usa `products`, enlazada mediante `source_product_id`.

## Instalación nueva

1. Copia el proyecto en `/Applications/XAMPP/xamppfiles/htdocs/stockflow/` y activa Apache y MySQL.
2. Respalda cualquier base existente llamada `devioz_shop_reparada`.
3. En phpMyAdmin, importa únicamente `database/devioz_shop_11604_completa.sql`.
4. No importes después `devioz_shop_reparada.sql`, `stockflow.sql` ni `upgrade_catalogo_maestro_11604.sql`: la base completa ya contiene el origen reparado, el esquema final y las migraciones una sola vez.
5. Ejecuta `CREAR_ADMIN_INICIAL.command` desde Terminal para definir la contraseña inicial. El asistente la lee sin mostrarla, genera un hash con PHP y rechaza el proceso si ya existe un administrador; el SQL no trae una contraseña predeterminada.
6. Verifica los resultados finales:

```sql
SELECT COUNT(*) AS source_rows FROM productos;
SELECT COUNT(*) AS operational_rows FROM products WHERE source_product_id IS NOT NULL;
SELECT status,source_count,imported_count FROM catalog_migrations ORDER BY id DESC LIMIT 1;
```

Los resultados esperados son `11604`, `11604` y `completed / 11604 / 11604`. El archivo completo elimina y recrea `devioz_shop_reparada`; por eso solo corresponde a una instalación nueva.

## Actualización no destructiva

Para una instalación existente y funcional:

1. Exporta y conserva un respaldo completo.
2. Comprueba que la base seleccionada sea `devioz_shop_reparada` y que `productos` tenga exactamente `11604` filas. Si conserva `store_settings.stockflow_schema_marker = catalogo_11604`, el instalador lo validará directamente; si es una instalación StockFlow anterior al marcador, usará la huella legacy documentada abajo.
3. Si la instalación profesional anterior aún no creó `store_featured_products`, importa una vez `database/upgrade_catalogo_unificado_profesional.sql` sobre esa base.
4. Ejecuta `INSTALAR_CATALOGO_11604.command`. El instalador busca el cliente MySQL de XAMPP, solicita las credenciales sin incluirlas en el proyecto y exige el marcador y seis tablas/seis columnas del esquema antes de ejecutar `database/upgrade_catalogo_maestro_11604.sql` y validar el resultado. Para una instalación anterior al marcador, exige además 12 tablas y 36 columnas de la huella legacy StockFlow, las `11604` filas y una confirmación que escriba exactamente el nombre de la base; solo entonces inscribe el marcador de forma no destructiva.
5. Si necesitas usar otra base, escribe su nombre exactamente en la confirmación adicional. Un nombre alternativo sin esa confirmación se rechaza antes de cualquier conexión.
6. Si el conteo no coincide, detente y consulta:

```sql
SELECT status,phase,details,source_count,imported_count
FROM catalog_migrations ORDER BY id DESC LIMIT 1;

SELECT *
FROM catalog_migration_issues
WHERE migration_key='catalogo_maestro_11604'
ORDER BY id;
```

No actives productos ni repitas la importación hasta entender y corregir la incidencia.

## Qué conserva la migración

La migración usa coexistencia: no sustituye físicamente el inventario anterior. Los datos previos se mantienen y además se toman instantáneas verificadas en:

- `legacy_products`
- `legacy_product_images`
- `legacy_inventory_movements`
- `legacy_combos`
- `legacy_combo_items`
- `legacy_store_featured_products`
- `legacy_stock_reservations`

Estas tablas son respaldo de solo lectura. Consúltalas desde `admin/respaldo_anterior.php` o mediante `SELECT`. No ejecutes escrituras o cambios de esquema sobre `legacy_*`. Para recuperar un dato, crea primero otro respaldo, compara la instantánea con la tabla activa y realiza una restauración manual controlada.

## Activación segura

Las 11,604 fichas maestras se importan con `active=0`, `sale_enabled=0`, `price=0` y `stock=0`. Desde **Administración → Todos los productos**:

1. Revisa proveedor, identidad, categoría y restricción.
2. Define costo, margen o precio y stock reales.
3. Activa y publica únicamente lotes revisados.
4. Comprueba una ficha, el carrito y un pedido de prueba antes de ampliar el lote.

La venta requiere simultáneamente `active=1`, `sale_enabled=1`, `restricted=0`, `stock>0` y `price>0`.

## Módulos incluidos

- Catálogo maestro paginado con búsqueda, filtros, exportación y acciones masivas.
- Respaldo navegable del inventario anterior.
- Catálogo público, carrito, pedidos, combos y pagos limitados a productos vendibles.
- Comparador de precios y fuentes de compra.
- Asistente con Ollama local opcional y respaldo determinista por reglas.
- Clientes, favoritos, delivery, cupones, reservas, contenido comercial y métricas.

## Ollama opcional

La base y la tienda funcionan sin Ollama. Para habilitar el modelo local configurado por defecto:

```bash
ollama pull llama3.2:3b
curl http://127.0.0.1:11434/api/tags
```

La configuración usa `SHOPPING_AI_PROVIDER`, `SHOPPING_AI_MODEL` y `SHOPPING_OLLAMA_URL`. Si el servicio no responde, las recomendaciones continúan en modo por reglas.

## Comprobaciones de entorno

```bash
/Applications/XAMPP/xamppfiles/bin/php -v
/Applications/XAMPP/xamppfiles/bin/mysql --version
```

Después comprueba `http://localhost/stockflow/`, el acceso administrativo, el total maestro de `11604`, el bloqueo de fichas no activadas y la vista de solo lectura `admin/respaldo_anterior.php`.

## Hosting y credenciales

Configura `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER` y `DB_PASS` mediante el entorno. `DB_NAME` debe apuntar a `devioz_shop_reparada` salvo que hayas renombrado la base deliberadamente. No guardes contraseñas reales en scripts, SQL, documentación ni control de versiones.
