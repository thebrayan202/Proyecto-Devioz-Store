# Catálogo maestro de 11,604 productos y rediseño profesional Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convertir las 11,604 fichas de `productos` en el inventario operativo de Devioz, conservar el sistema anterior como respaldo y entregar la tienda pública y administración con el diseño profesional aprobado.

**Architecture:** `productos` continúa como catálogo de origen y `products` pasa a ser la capa operativa con stock, costos, precio final, margen y publicación. Una migración idempotente respalda primero todas las relaciones antiguas en `legacy_*`, importa el catálogo desactivado y crea índices; la aplicación consulta servicios PHP enfocados para administración, tienda e IA.

**Tech Stack:** PHP 8.x estricto, PDO, MySQL/MariaDB 10.4+, HTML5, CSS3, JavaScript sin framework, Ollama HTTP local, pruebas PHP ejecutables por CLI.

**Spec:** `docs/superpowers/specs/2026-09-17-catalogo-maestro-12000-diseno-referencia-design.md`

## Global Constraints

- Mantener compatibilidad con PHP 8.x y MariaDB 10.4+ de XAMPP.
- Importar exactamente las 11,604 fichas válidas incluidas en `productos`; cualquier diferencia debe quedar registrada.
- Los productos importados comienzan con `stock=0`, `active=0` y `sale_enabled=0`.
- La visibilidad pública exige `active=1`, `sale_enabled=1`, `restricted=0`, `stock>0` y `price>0`.
- El margen global inicial es 25 %, editable, y no sustituye el precio final sin confirmación.
- No borrar el inventario ni las relaciones antiguas; conservarlos en tablas `legacy_*` verificadas.
- No copiar marcas ni recursos promocionales de las capturas de referencia.
- Excluir productos restringidos por edad de tienda, búsqueda, recomendaciones y carritos.
- Usar consultas preparadas, CSRF y confirmación para acciones masivas.
- No cargar las 11,604 filas completas en el navegador.

---

### Task 1: Contrato del nuevo catálogo y reglas puras

**Files:**
- Create: `includes/master_catalog.php`
- Create: `tests/master_catalog_test.php`
- Modify: `includes/storefront.php`

**Interfaces:**
- Produces: `master_product_visibility_sql(string $alias='p'): string`, `master_suggested_price(?float $supplierPrice, ?float $margin, float $globalMargin=25.0): ?float`, `master_product_status(array $product): string`, `master_catalog_filters(array $input): array`.
- Consumes: ninguna dependencia nueva.

- [ ] **Step 1: Write the failing contract test**

```php
<?php
declare(strict_types=1);
require_once __DIR__.'/../includes/master_catalog.php';
function mc_same(mixed $e,mixed $a,string $m): void { if($e!==$a) throw new RuntimeException($m); }
mc_same(12.50,master_suggested_price(10.00,null,25.0),'precio sugerido');
mc_same(null,master_suggested_price(0.00,null,25.0),'precio ausente');
mc_same('published',master_product_status(['active'=>1,'sale_enabled'=>1,'restricted'=>0,'stock'=>2,'price'=>5]),'publicado');
mc_same('restricted',master_product_status(['restricted'=>1]),'restringido');
$sql=master_product_visibility_sql();
foreach(['active = 1','sale_enabled = 1','restricted = 0','stock > 0','price > 0'] as $part) if(!str_contains($sql,$part)) throw new RuntimeException($part);
$filters=master_catalog_filters(['rows'=>'999','page'=>'-1','status'=>'DROP','sort'=>'bad']);
mc_same(25,$filters['rows'],'filas'); mc_same(1,$filters['page'],'página'); mc_same('name',$filters['sort'],'orden');
echo "master_catalog_test: OK\n";
```

- [ ] **Step 2: Run the test and confirm the missing file failure**

Run: `php tests/master_catalog_test.php`  
Expected: FAIL because `includes/master_catalog.php` does not exist.

- [ ] **Step 3: Implement the pure rules**

```php
<?php
declare(strict_types=1);
function master_product_visibility_sql(string $alias='p'): string {
    return "$alias.active = 1 AND $alias.sale_enabled = 1 AND $alias.restricted = 0 AND $alias.stock > 0 AND $alias.price > 0";
}
function master_suggested_price(?float $supplierPrice,?float $margin,float $globalMargin=25.0): ?float {
    if($supplierPrice===null||$supplierPrice<=0)return null;
    $pct=max(0.0,min(500.0,$margin??$globalMargin));
    return round($supplierPrice*(1+$pct/100),2);
}
function master_product_status(array $p): string {
    if((int)($p['restricted']??0)===1)return 'restricted';
    if((int)($p['active']??0)===1&&(int)($p['sale_enabled']??0)===1&&(int)($p['stock']??0)>0&&(float)($p['price']??0)>0)return 'published';
    if((int)($p['active']??0)===1&&((int)($p['stock']??0)<=0))return 'out_of_stock';
    if((float)($p['cost_price']??0)>0&&(float)($p['price']??0)>0)return 'ready';
    return 'pending';
}
```

Complete `master_catalog_filters()` with allowlists: rows `[25,50,100]`, sort `[name,source_name,category,supplier_price,cost_price,price,stock,updated_at]`, dir `[asc,desc]`, and statuses `['','pending','ready','published','out_of_stock','restricted']`. Update `storefront_product_scope_sql()` to use `master_product_visibility_sql()`.

- [ ] **Step 4: Run focused tests**

Run: `php tests/master_catalog_test.php && php tests/storefront_test.php`  
Expected: both print `OK`; update `storefront_test.php` to assert all five visibility predicates.

- [ ] **Step 5: Commit**

```bash
git add includes/master_catalog.php includes/storefront.php tests/master_catalog_test.php tests/storefront_test.php
git commit -m "feat: define master catalog rules"
```

### Task 2: Migración idempotente y respaldo histórico

**Files:**
- Create: `database/upgrade_catalogo_maestro_11604.sql`
- Create: `tests/master_catalog_migration_test.php`
- Modify: `database/stockflow.sql`

**Interfaces:**
- Consumes: campos y estados de Task 1.
- Produces: tablas `catalog_migrations`, `catalog_migration_issues`, `legacy_products`, `legacy_product_images`, `legacy_inventory_movements`, `legacy_combos`, `legacy_combo_items`, `legacy_store_featured_products`, `legacy_stock_reservations`; columnas nuevas de `products`.

- [ ] **Step 1: Write a structural migration test**

```php
<?php
$sql=file_get_contents(__DIR__.'/../database/upgrade_catalogo_maestro_11604.sql');
foreach(['catalog_migrations','legacy_products','source_product_id','sale_enabled','restricted','UNIQUE KEY uq_products_source','catalog_migration_issues'] as $needle){
    if(!str_contains($sql,$needle)) throw new RuntimeException('Falta '.$needle);
}
foreach(['stock = 0','active = 0','sale_enabled = 0'] as $needle){
    if(!str_contains($sql,$needle)) throw new RuntimeException('Valor seguro ausente: '.$needle);
}
if(str_contains(strtoupper($sql),'TRUNCATE TABLE PRODUCTS')) throw new RuntimeException('Migración destructiva');
echo "master_catalog_migration_test: OK\n";
```

- [ ] **Step 2: Run the test and verify it fails**

Run: `php tests/master_catalog_migration_test.php`  
Expected: FAIL because the migration file is absent.

- [ ] **Step 3: Implement migration metadata and operational columns**

Add SQL equivalent to:

```sql
CREATE TABLE IF NOT EXISTS catalog_migrations (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  migration_key VARCHAR(80) NOT NULL UNIQUE,
  source_count INT UNSIGNED NOT NULL,
  imported_count INT UNSIGNED NOT NULL DEFAULT 0,
  status ENUM('running','completed','failed') NOT NULL,
  details TEXT NULL,
  started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  completed_at DATETIME NULL
) ENGINE=InnoDB;

ALTER TABLE products
  ADD COLUMN IF NOT EXISTS source_product_id INT NULL,
  ADD COLUMN IF NOT EXISTS source_name VARCHAR(100) NOT NULL DEFAULT 'Devioz',
  ADD COLUMN IF NOT EXISTS ean VARCHAR(100) NULL,
  ADD COLUMN IF NOT EXISTS brand VARCHAR(150) NULL,
  ADD COLUMN IF NOT EXISTS presentation VARCHAR(150) NULL,
  ADD COLUMN IF NOT EXISTS supplier_price DECIMAL(10,2) NULL,
  ADD COLUMN IF NOT EXISTS suggested_price DECIMAL(10,2) NULL,
  ADD COLUMN IF NOT EXISTS margin_pct DECIMAL(7,2) NULL,
  ADD COLUMN IF NOT EXISTS sale_enabled TINYINT(1) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS restricted TINYINT(1) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS source_updated_at DATETIME NULL,
  ADD UNIQUE KEY uq_products_source (source_product_id),
  ADD INDEX idx_products_public (active,sale_enabled,restricted,stock,price),
  ADD INDEX idx_products_source_category (source_name,category),
  ADD INDEX idx_products_ean (ean);
```

Implement copy-and-count checks for every dependent table before inserting catalog rows. Populate operational products with `code=CONCAT('SRC-',LPAD(id_producto,8,'0'))`, `supplier_price=precio_actual`, `suggested_price=ROUND(precio_actual*1.25,2)`, and safe zero/inactive defaults. Record invalid rows in `catalog_migration_issues`.

- [ ] **Step 4: Add the same final schema to fresh installation SQL**

Modify `database/stockflow.sql` so new installations create the final columns and indexes, but do not embed a second copy of the 11,604 INSERT rows; the full integrated deliverable is assembled in Task 11.

- [ ] **Step 5: Verify structure and idempotency markers**

Run: `php tests/master_catalog_migration_test.php && rg -n "migration_key|ON DUPLICATE KEY|uq_products_source" database/upgrade_catalogo_maestro_11604.sql`  
Expected: test prints `OK`; every required marker is present.

- [ ] **Step 6: Commit**

```bash
git add database/upgrade_catalogo_maestro_11604.sql database/stockflow.sql tests/master_catalog_migration_test.php
git commit -m "feat: migrate 11604 products with verified legacy backup"
```

### Task 3: Consulta paginada del catálogo maestro

**Files:**
- Modify: `includes/master_catalog.php`
- Modify: `admin/todos_productos.php`
- Modify: `admin/exportar_productos.php`
- Create: `tests/master_catalog_query_test.php`

**Interfaces:**
- Consumes: `master_catalog_filters()` and migrated `products`.
- Produces: `master_catalog_where(array $filters): array`, `fetch_master_catalog(PDO $pdo,array $filters): array`, `master_catalog_summary(PDO $pdo): array`.

- [ ] **Step 1: Add tests for allowlisted SQL and paging**

```php
<?php
declare(strict_types=1);
require_once __DIR__.'/../includes/master_catalog.php';
$f=master_catalog_filters(['q'=>'leche','source'=>'Metro','status'=>'published','rows'=>'50','page'=>'2','sort'=>'stock','dir'=>'desc']);
$w=master_catalog_where($f);
foreach([':q',':source','active = 1','sale_enabled = 1'] as $part) if(!str_contains($w['sql'],$part)) throw new RuntimeException($part);
if(str_contains($w['sql'],'leche')) throw new RuntimeException('Valor interpolado');
if($f['rows']!==50||$f['page']!==2||$f['sort']!=='stock') throw new RuntimeException('Filtros');
echo "master_catalog_query_test: OK\n";
```

- [ ] **Step 2: Run it and confirm missing functions**

Run: `php tests/master_catalog_query_test.php`  
Expected: FAIL for undefined `master_catalog_where()`.

- [ ] **Step 3: Implement prepared filters and page query**

Use named parameters for `q`, `source`, `category`, price bounds and stock bounds. Map status names to fixed SQL fragments and map sort names to fixed column names. `fetch_master_catalog()` must run `COUNT(*)` and then `LIMIT :limit OFFSET :offset`, binding both as `PDO::PARAM_INT`.

```php
function master_catalog_summary(PDO $pdo): array {
    return $pdo->query("SELECT COUNT(*) total,
      SUM(active=1 AND sale_enabled=1 AND restricted=0 AND stock>0 AND price>0) published,
      SUM(stock<=min_stock) low_stock,
      SUM(cost_price<=0) missing_cost,
      SUM(price<=0) missing_price,
      COALESCE(SUM(cost_price*stock),0) inventory_cost,
      COALESCE(SUM((price-cost_price)*stock),0) potential_profit
      FROM products")->fetch() ?: [];
}
```

- [ ] **Step 4: Rebuild the table and secure CSV export**

Render only the current page in `admin/todos_productos.php`; include origin, EAN, costs, suggested/final price, margin, stock, utility and state. In `admin/exportar_productos.php`, reuse `master_catalog_where()` and prefix cells beginning with `=`, `+`, `-`, or `@` with `'` before `fputcsv()`.

- [ ] **Step 5: Run tests**

Run: `php tests/master_catalog_query_test.php && php tests/export_security_test.php && php tests/unified_catalog_test.php`  
Expected: all print `OK`.

- [ ] **Step 6: Commit**

```bash
git add includes/master_catalog.php admin/todos_productos.php admin/exportar_productos.php tests/master_catalog_query_test.php tests/export_security_test.php
git commit -m "feat: add paginated master catalog administration"
```

### Task 4: Edición y activación masiva segura

**Files:**
- Create: `admin/productos_masivo.php`
- Modify: `admin/producto_guardar.php`
- Modify: `admin/todos_productos.php`
- Create: `tests/master_catalog_actions_test.php`

**Interfaces:**
- Consumes: filter contract from Task 3 and `verify_csrf()`.
- Produces: `master_bulk_selection(array $post): array`, `master_bulk_changes(array $post): array`, POST actions `preview` and `apply`.

- [ ] **Step 1: Test selection and value validation**

```php
<?php
declare(strict_types=1);
require_once __DIR__.'/../includes/master_catalog.php';
$ids=master_bulk_selection(['ids'=>['2','2','9','-1','x']]);
if($ids!==[2,9]) throw new RuntimeException('IDs');
$changes=master_bulk_changes(['active'=>'1','sale_enabled'=>'1','margin_pct'=>'30','min_stock'=>'5']);
if($changes!==['active'=>1,'sale_enabled'=>1,'margin_pct'=>30.0,'min_stock'=>5]) throw new RuntimeException('Cambios');
try{ master_bulk_changes(['margin_pct'=>'900']); throw new RuntimeException('Debió fallar'); }catch(InvalidArgumentException){}
echo "master_catalog_actions_test: OK\n";
```

- [ ] **Step 2: Run test and confirm missing functions**

Run: `php tests/master_catalog_actions_test.php`  
Expected: FAIL for undefined bulk functions.

- [ ] **Step 3: Implement validators and preview/apply flow**

`preview` returns a confirmation page with count and summarized changes. `apply` requires a signed selection token stored in session, opens a transaction, updates batches of at most 500 IDs, writes one `activity_log` entry and redirects with a flash message. Publishing must reject rows with `restricted=1`, `stock<=0`, `price<=0`, or `cost_price<=0`.

```php
$allowed=['active','sale_enabled','margin_pct','min_stock','price'];
$set=[];$params=[];
foreach($changes as $column=>$value){
    if(!in_array($column,$allowed,true)) throw new InvalidArgumentException('Campo no permitido.');
    $set[]="$column = ?"; $params[]=$value;
}
```

- [ ] **Step 4: Add table controls**

Add checkboxes, select-current-page, filters by source/category/status, action selector, values, preview button and explicit confirmation text containing the affected count.

- [ ] **Step 5: Run tests**

Run: `php tests/master_catalog_actions_test.php && php tests/unified_catalog_actions_test.php`  
Expected: both print `OK`.

- [ ] **Step 6: Commit**

```bash
git add includes/master_catalog.php admin/productos_masivo.php admin/producto_guardar.php admin/todos_productos.php tests/master_catalog_actions_test.php
git commit -m "feat: add confirmed bulk catalog operations"
```

### Task 5: Respaldo anterior de solo lectura

**Files:**
- Create: `admin/respaldo_anterior.php`
- Modify: `includes/admin_header.php`
- Create: `tests/legacy_backup_view_test.php`

**Interfaces:**
- Consumes: `legacy_*` tables from Task 2 and admin authentication.
- Produces: read-only paginated viewer with product, movements, images and old combos; no POST routes.

- [ ] **Step 1: Write a static safety test**

```php
<?php
$page=file_get_contents(__DIR__.'/../admin/respaldo_anterior.php');
foreach(['legacy_products','legacy_inventory_movements','LIMIT :limit','OFFSET :offset'] as $n) if(!str_contains($page,$n)) throw new RuntimeException($n);
foreach(['DELETE FROM legacy_','UPDATE legacy_','INSERT INTO legacy_'] as $n) if(str_contains(strtoupper($page),strtoupper($n))) throw new RuntimeException('Escritura histórica');
echo "legacy_backup_view_test: OK\n";
```

- [ ] **Step 2: Run test and verify absent page failure**

Run: `php tests/legacy_backup_view_test.php`  
Expected: FAIL because the page is absent.

- [ ] **Step 3: Implement the read-only page and navigation**

Use prepared `LIKE` search and 25/50/100 pagination. Show legacy totals and a product detail link containing its old movements and combos; do not create forms that mutate `legacy_*`. Change the existing “Descargar respaldo” sidebar item to “Respaldo anterior” pointing to this page, while keeping database download as a secondary action.

- [ ] **Step 4: Run navigation and viewer tests**

Run: `php tests/legacy_backup_view_test.php && php tests/admin_navigation_test.php`  
Expected: both print `OK`; navigation test includes `Respaldo anterior`.

- [ ] **Step 5: Commit**

```bash
git add admin/respaldo_anterior.php includes/admin_header.php tests/legacy_backup_view_test.php tests/admin_navigation_test.php
git commit -m "feat: expose read-only legacy inventory backup"
```

### Task 6: Tienda pública con catálogo maestro

**Files:**
- Modify: `includes/storefront.php`
- Modify: `includes/public_header.php`
- Modify: `index.php`
- Modify: `catalogo_completo.php`
- Modify: `api/productos.php`
- Modify: `assets/css/styles.css`
- Modify: `assets/js/app.js`
- Create: `tests/public_master_catalog_test.php`

**Interfaces:**
- Consumes: visibility SQL from Task 1 and operational products from Task 2.
- Produces: public search/filter query, 24/48 pagination, home sections and product cards.

- [ ] **Step 1: Add a public-scope regression test**

```php
<?php
$files=['includes/storefront.php','catalogo_completo.php','api/productos.php'];
foreach($files as $file){$s=file_get_contents(__DIR__.'/../'.$file);foreach(['sale_enabled','restricted'] as $n)if(!str_contains($s,$n))throw new RuntimeException("$file: $n");}
$header=file_get_contents(__DIR__.'/../includes/public_header.php');
foreach(['Categorías','smartStoreSearch','Mi cuenta','Mi lista'] as $n)if(!str_contains($header,$n))throw new RuntimeException($n);
echo "public_master_catalog_test: OK\n";
```

- [ ] **Step 2: Run it and verify the missing predicates**

Run: `php tests/public_master_catalog_test.php`  
Expected: FAIL because current public SQL does not require `sale_enabled` and `restricted`.

- [ ] **Step 3: Update every public product query**

Reuse `master_product_visibility_sql()` in home sections, catalog, API, related products, favorites and search. Add category, price, delivery and sort filters through prepared parameters; return 24 or 48 items per page.

- [ ] **Step 4: Implement the approved storefront layout**

Keep the existing Devioz logo and implement: benefit strip, navy header, categories button, large smart search, account/cart, delivery row, managed hero, category circles, offers, IA recommendations, best sellers, combos, floating assistant and side cart. Add semantic headings, visible focus states and responsive breakpoints at 1024 px and 720 px.

- [ ] **Step 5: Wire search and responsive interactions**

In `assets/js/app.js`, submit normal queries to `catalogo_completo.php?q=...`; phrases containing budget intent may open the assistant with the encoded request. The mobile menu and cart drawer must close on Escape and restore focus to the trigger.

- [ ] **Step 6: Run public tests and syntax checks**

Run: `php tests/public_master_catalog_test.php && php tests/storefront_test.php && php -l index.php && php -l catalogo_completo.php && php -l api/productos.php`  
Expected: tests print `OK`; every syntax check reports no errors.

- [ ] **Step 7: Commit**

```bash
git add includes/storefront.php includes/public_header.php index.php catalogo_completo.php api/productos.php assets/css/styles.css assets/js/app.js tests/public_master_catalog_test.php
git commit -m "feat: redesign public store for master inventory"
```

### Task 7: Administración y dashboard profesional

**Files:**
- Modify: `includes/admin_header.php`
- Modify: `admin/index.php`
- Modify: `admin/precios.php`
- Modify: `assets/css/styles.css`
- Modify: `assets/js/app.js`
- Create: `tests/admin_dashboard_11604_test.php`

**Interfaces:**
- Consumes: `master_catalog_summary()` and order/movement snapshots.
- Produces: dashboard KPIs, chart data arrays, alerts, top profitability and global admin search.

- [ ] **Step 1: Add dashboard content assertions**

```php
<?php
$page=file_get_contents(__DIR__.'/../admin/index.php');
foreach(['Productos maestros','Productos publicados','Ganancia real','Ganancia potencial','Sin costo','Sin precio'] as $n)if(!str_contains($page,$n))throw new RuntimeException($n);
$header=file_get_contents(__DIR__.'/../includes/admin_header.php');
foreach(['Todos los productos','Proveedores','Rentabilidad','Respaldo anterior'] as $n)if(!str_contains($header,$n))throw new RuntimeException($n);
echo "admin_dashboard_11604_test: OK\n";
```

- [ ] **Step 2: Run and confirm expected failures**

Run: `php tests/admin_dashboard_11604_test.php`  
Expected: FAIL for dashboard labels not yet implemented.

- [ ] **Step 3: Implement dashboard queries**

Use one master summary query, one approved-orders daily aggregate for the last 30 days, one movements aggregate, and limited alert/top-product queries. Do not query all products. Real profit comes from approved `yape_order_items.profit`; potential profit comes from current `products` stock.

```sql
SELECT DATE(o.created_at) day, SUM(i.subtotal) sales, SUM(i.profit) profit
FROM yape_order_items i
JOIN yape_orders o ON o.id=i.order_id
WHERE o.status='aprobado' AND o.created_at>=CURRENT_DATE-INTERVAL 29 DAY
GROUP BY DATE(o.created_at) ORDER BY day;
```

- [ ] **Step 4: Build the approved admin presentation**

Use navy fixed sidebar, white workspace, global search, five KPI cards, sales/profit chart, inventory alerts, AI insight card and dense responsive table treatment. On screens below 900 px the sidebar becomes a drawer and tables retain horizontal scrolling.

- [ ] **Step 5: Run dashboard and navigation tests**

Run: `php tests/admin_dashboard_11604_test.php && php tests/admin_navigation_test.php && php tests/profitability_labels_test.php && php -l admin/index.php && php -l admin/precios.php`  
Expected: all tests print `OK`; syntax valid.

- [ ] **Step 6: Commit**

```bash
git add includes/admin_header.php admin/index.php admin/precios.php assets/css/styles.css assets/js/app.js tests/admin_dashboard_11604_test.php
git commit -m "feat: deliver professional inventory dashboard"
```

### Task 8: Inventario, movimientos, combos, reservas y checkout

**Files:**
- Modify: `admin/productos.php`
- Modify: `admin/producto_form.php`
- Modify: `admin/producto_guardar.php`
- Modify: `admin/movimientos.php`
- Modify: `admin/combos.php`
- Modify: `admin/reservas.php`
- Modify: `api/checkout_quote.php`
- Modify: `api/yape_order.php`
- Modify: `admin/pedidos_yape.php`
- Create: `tests/sale_eligibility_test.php`

**Interfaces:**
- Consumes: visibility/status rules and migrated operational schema.
- Produces: `sale_eligible_product(array $product,int $quantity=1): bool`; new operations use only `products` IDs.

- [ ] **Step 1: Add sale eligibility tests**

```php
<?php
declare(strict_types=1);
require_once __DIR__.'/../includes/master_catalog.php';
$ok=['active'=>1,'sale_enabled'=>1,'restricted'=>0,'stock'=>4,'price'=>6.5];
if(!sale_eligible_product($ok,2))throw new RuntimeException('Producto válido');
foreach(['active','sale_enabled'] as $field){$p=$ok;$p[$field]=0;if(sale_eligible_product($p,1))throw new RuntimeException($field);}
$p=$ok;$p['restricted']=1;if(sale_eligible_product($p,1))throw new RuntimeException('restricted');
$p=$ok;$p['stock']=1;if(sale_eligible_product($p,2))throw new RuntimeException('stock');
echo "sale_eligibility_test: OK\n";
```

- [ ] **Step 2: Run and verify undefined function failure**

Run: `php tests/sale_eligibility_test.php`  
Expected: FAIL for undefined `sale_eligible_product()`.

- [ ] **Step 3: Implement eligibility and enforce it transactionally**

Add the helper to `master_catalog.php`. In checkout/order approval, select products `FOR UPDATE`, evaluate eligibility with requested units, then calculate using database price and cost rather than browser values. Reject restricted/inactive/unpublished items with HTTP 409 and a clear message.

- [ ] **Step 4: Adapt operational pages**

Expose source, EAN, supplier price, suggested price, margin, publication and restriction fields in forms. Product selectors in movements and combos must use server-side search instead of loading 11,604 `<option>` elements. Reservations join only the new operational products; old reservations remain in `legacy_stock_reservations`.

- [ ] **Step 5: Run transactional regressions and syntax checks**

Run: `php tests/sale_eligibility_test.php && php tests/commercial_content_test.php && php -l api/yape_order.php && php -l admin/movimientos.php && php -l admin/combos.php`  
Expected: tests print `OK`; syntax valid.

- [ ] **Step 6: Commit**

```bash
git add includes/master_catalog.php admin/productos.php admin/producto_form.php admin/producto_guardar.php admin/movimientos.php admin/combos.php admin/reservas.php api/checkout_quote.php api/yape_order.php admin/pedidos_yape.php tests/sale_eligibility_test.php
git commit -m "feat: enforce master inventory across sales operations"
```

### Task 9: IA limitada al inventario vendible

**Files:**
- Modify: `includes/ai_recommendations.php`
- Modify: `includes/shopping_ai.php`
- Modify: `includes/shopping_agent.php`
- Modify: `api/recomendaciones.php`
- Modify: `asistente_compras.php`
- Modify: `assets/js/shopping_chat.js`
- Modify: `assets/css/shopping_chat.css`
- Modify: `tests/ai_recommendations_test.php`

**Interfaces:**
- Consumes: `master_product_visibility_sql()` and `sale_eligible_product()`.
- Produces: validated recommendation payloads `{id:int, qty:int}` using at most 60 DB candidates.

- [ ] **Step 1: Expand AI tests for publication and restrictions**

Add candidates with `sale_enabled=0`, `restricted=1`, insufficient stock and fake model IDs. Assert only eligible real IDs survive and total cost never exceeds budget.

```php
$validated=validate_model_recommendations(
 [['id'=>999,'qty'=>1],['id'=>1,'qty'=>9]],
 [1=>['id'=>1,'price'=>5.0,'stock'=>2,'active'=>1,'sale_enabled'=>1,'restricted'=>0]],
 12.0
);
if($validated!==[['id'=>1,'qty'=>2]]) throw new RuntimeException('Validación final');
```

- [ ] **Step 2: Run test and confirm it fails under new fields**

Run: `php tests/ai_recommendations_test.php`  
Expected: FAIL until the candidate and validation scopes enforce the new contract.

- [ ] **Step 3: Update candidate query and model validation**

`recommendation_candidates()` must use all visibility predicates and `LIMIT 60`. The server validates IDs, quantities, prices, stock, restriction and budget after Ollama responds. No SQL, credentials, costs or hidden fields are included in the prompt.

- [ ] **Step 4: Preserve deterministic fallback**

If Ollama times out or returns invalid JSON, use existing rule-based ranking over the same candidate set. Require user confirmation before calling the cart-add path and increment `ai_usage_daily.rule_fallbacks` or `ollama_answers` appropriately.

- [ ] **Step 5: Run AI tests and syntax checks**

Run: `php tests/ai_recommendations_test.php && php tests/shopping_agent_test.php && php -l api/recomendaciones.php && php -l asistente_compras.php`  
Expected: tests print `OK`; syntax valid without requiring Ollama online.

- [ ] **Step 6: Commit**

```bash
git add includes/ai_recommendations.php includes/shopping_ai.php includes/shopping_agent.php api/recomendaciones.php asistente_compras.php assets/js/shopping_chat.js assets/css/shopping_chat.css tests/ai_recommendations_test.php
git commit -m "feat: constrain shopping AI to sellable inventory"
```

### Task 10: Contenido comercial y búsqueda eficiente de productos

**Files:**
- Modify: `admin/contenido_tienda.php`
- Create: `api/admin_product_search.php`
- Modify: `assets/js/app.js`
- Modify: `tests/commercial_content_test.php`
- Create: `tests/admin_product_search_test.php`

**Interfaces:**
- Consumes: operational products and admin session.
- Produces: authenticated JSON search `{items:[{id,name,code,stock,price}]}` limited to 20 results.

- [ ] **Step 1: Add endpoint safety test**

```php
<?php
$api=file_get_contents(__DIR__.'/../api/admin_product_search.php');
foreach(['require_admin','LIMIT 20','sale_enabled','json_encode'] as $n)if(!str_contains($api,$n))throw new RuntimeException($n);
if(!str_contains($api,'prepare('))throw new RuntimeException('Consulta preparada');
echo "admin_product_search_test: OK\n";
```

- [ ] **Step 2: Run and verify absent endpoint failure**

Run: `php tests/admin_product_search_test.php`  
Expected: FAIL because the endpoint is absent.

- [ ] **Step 3: Implement authenticated product autocomplete**

Search by name, code or EAN with one bounded `q` parameter and return at most 20 rows. Use it in featured-product, combos and movements selectors; remove queries that fetch every active product.

- [ ] **Step 4: Keep public content valid**

Only allow featuring products meeting the public visibility scope. Banner URLs continue through `commercial_safe_url()` and scheduled dates remain honored.

- [ ] **Step 5: Run tests**

Run: `php tests/admin_product_search_test.php && php tests/commercial_content_test.php && php -l admin/contenido_tienda.php && php -l api/admin_product_search.php`  
Expected: tests print `OK`; syntax valid.

- [ ] **Step 6: Commit**

```bash
git add admin/contenido_tienda.php api/admin_product_search.php assets/js/app.js tests/admin_product_search_test.php tests/commercial_content_test.php
git commit -m "perf: add bounded admin product lookup"
```

### Task 11: Instaladores, documentación y base completa

**Files:**
- Create: `INSTALAR_CATALOGO_11604.command`
- Create: `LEEME_CATALOGO_11604.txt`
- Create: `database/devioz_shop_11604_completa.sql`
- Modify: `README.md`
- Modify: `BASE_DE_DATOS_DEVIOZ.md`
- Create: `tests/deliverables_test.php`

**Interfaces:**
- Consumes: final schema and migration from Tasks 2–10.
- Produces: update installer, fresh database dump and post-install verification instructions.

- [ ] **Step 1: Add deliverables test**

```php
<?php
$required=['INSTALAR_CATALOGO_11604.command','LEEME_CATALOGO_11604.txt','database/devioz_shop_11604_completa.sql'];
foreach($required as $file)if(!is_file(__DIR__.'/../'.$file)||filesize(__DIR__.'/../'.$file)===0)throw new RuntimeException($file);
$sql=file_get_contents(__DIR__.'/../database/devioz_shop_11604_completa.sql');
foreach(['CREATE TABLE `productos`','source_product_id','catalog_migrations'] as $n)if(!str_contains($sql,$n))throw new RuntimeException($n);
echo "deliverables_test: OK\n";
```

- [ ] **Step 2: Run and verify missing deliverables**

Run: `php tests/deliverables_test.php`  
Expected: FAIL because deliverables do not exist.

- [ ] **Step 3: Build the installation artifacts**

Assemble the full SQL from the repaired source catalog plus the final schema/migration once, ensuring there is only one active definition for each table. The `.command` script must locate XAMPP’s MySQL client, prompt for database credentials without embedding them, import the update SQL and run these checks:

```sql
SELECT COUNT(*) AS source_rows FROM productos;
SELECT COUNT(*) AS operational_rows FROM products WHERE source_product_id IS NOT NULL;
SELECT status,source_count,imported_count FROM catalog_migrations ORDER BY id DESC LIMIT 1;
```

- [ ] **Step 4: Document update, fresh install and recovery**

Provide exact XAMPP folder location, database import order, expected count `11604`, safe activation steps, Ollama optional setup, and read-only recovery from `legacy_*`. State that a count mismatch means the user must stop and inspect `catalog_migration_issues`.

- [ ] **Step 5: Run deliverable checks**

Run: `php tests/deliverables_test.php && bash -n INSTALAR_CATALOGO_11604.command`  
Expected: test prints `OK`; shell syntax check exits 0.

- [ ] **Step 6: Commit**

```bash
git add INSTALAR_CATALOGO_11604.command LEEME_CATALOGO_11604.txt database/devioz_shop_11604_completa.sql README.md BASE_DE_DATOS_DEVIOZ.md tests/deliverables_test.php
git commit -m "docs: add XAMPP installers for 11604 product catalog"
```

### Task 12: Verificación integral y paquete final

**Files:**
- Modify only files required by failures found during this task.
- Create: `VERIFICACION_FINAL.md`

**Interfaces:**
- Consumes: all previous deliverables.
- Produces: evidence report and final ZIP excluding `.git`, temporary files and secrets.

- [ ] **Step 1: Run every PHP test**

Run:

```bash
set -e
for test in tests/*_test.php; do php "$test"; done
```

Expected: every file prints its `OK` line and the loop exits 0.

- [ ] **Step 2: Lint all application PHP**

Run:

```bash
set -e
find . -path './.git' -prune -o -name '*.php' -type f -print0 | xargs -0 -n1 php -l
```

Expected: every file reports `No syntax errors detected`.

- [ ] **Step 3: Verify migration and performance invariants**

Run:

```bash
rg -n "FROM products.*fetchAll|SELECT .* FROM products" admin includes api
rg -n "LIMIT (20|24|25|48|50|60|100)|OFFSET" admin includes api
rg -n "sale_enabled|restricted" index.php catalogo_completo.php includes/storefront.php includes/ai_recommendations.php api/productos.php api/yape_order.php
```

Expected: no all-catalog dropdown remains; public/AI/order paths include publication restrictions; list pages are bounded.

- [ ] **Step 4: Perform browser acceptance in XAMPP**

Verify desktop and 390 px mobile widths: home, category search, catalog paging, assistant fallback, cart, checkout, admin login, dashboard, all-products filters, bulk preview/apply, movement, profitability, banners and legacy viewer. Confirm browser console has no errors and no restricted/unpublished item can enter the cart.

- [ ] **Step 5: Record evidence**

Create `VERIFICACION_FINAL.md` listing commands, exit results, source/imported counts, pages checked, mobile width, and any environmental limitation such as unavailable local MySQL or Ollama. Do not mark an unavailable check as passed.

- [ ] **Step 6: Request code review**

Use `superpowers:requesting-code-review`; fix all correctness and security findings, then rerun Steps 1–4.

- [ ] **Step 7: Create the clean ZIP**

```bash
cd ..
zip -r stockflow-devioz-profesional-11604.zip stockflow \
  -x 'stockflow/.git/*' 'stockflow/config/*.local.php' 'stockflow/assets/uploads/receipts/*' '*.DS_Store'
```

Expected: ZIP contains application, migration, full SQL, tests and instructions, but no repository metadata, local secrets or customer receipts.

- [ ] **Step 8: Commit verification report**

```bash
git add VERIFICACION_FINAL.md
git commit -m "test: document final 11604 catalog verification"
```
