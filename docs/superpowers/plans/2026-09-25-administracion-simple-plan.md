# Administración simple Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reducir decisiones y clics diarios mediante pendientes priorizados, estados comprensibles, edición rápida, creación guiada de combos y un inicio operativo.

**Architecture:** Consultas pequeñas calculan tareas accionables; los estados visibles se derivan de las reglas maestras existentes. Las ediciones rápidas usan un endpoint admin estricto y el asistente de combos reutiliza las mismas reglas de stock del checkout.

**Tech Stack:** PHP 8+, PDO MySQL/MariaDB, JavaScript sin framework, CSS existente.

**Spec:** `docs/superpowers/specs/2026-09-25-nutricion-y-checkout-dinamico-design.md`

## Global Constraints

- No se agregan módulos nuevos al menú principal.
- Estados de UI: Visible, Oculto y Sin stock; los campos técnicos permanecen internos.
- Solo precio, stock, mínimo y visibilidad se editan en línea.
- Un combo nunca se publica vacío, restringido o sin capacidad real.
- El panel prioriza acciones; estadísticas avanzadas quedan ocultas.

## Review Focus

- Dos ediciones rápidas simultáneas: responder conflicto y no perder el valor reciente.
- Producto con stock pero precio cero: no etiquetarlo Visible.
- Producto oculto que llega a stock cero: conservar la intención manual al reponer.
- Combo con el mismo producto repetido: consolidar cantidades antes de calcular capacidad.
- Instalación sin pedidos o nutrición: panel muestra cero/estado vacío sin fallar.

---

### Task 1: Estado simple y edición rápida

**Files:**
- Modify: `includes/master_catalog.php`
- Create: `api/admin_product_quick_update.php`
- Modify: `admin/todos_productos.php`
- Modify: `assets/js/app.js`
- Modify: `assets/css/styles.css`
- Create: `tests/product_simple_status_test.php`
- Create: `tests/product_quick_edit_test.cjs`

**Interfaces:**
- Produces: `master_product_simple_status(array $product): array{key:string,label:string}`.
- Endpoint consumes `{id,field,value,updated_at,csrf_token}` and returns `{success,field,value,status,updated_at}`.

- [ ] **Step 1: Write failing status tests**

```php
assert(master_product_simple_status(['stock'=>0,'price'=>10,'active'=>1,'sale_enabled'=>1,'restricted'=>0,'catalog_scope'=>'master'])['key']==='out_of_stock');
assert(master_product_simple_status(['stock'=>5,'price'=>10,'active'=>0,'sale_enabled'=>0,'restricted'=>0,'catalog_scope'=>'master'])['key']==='hidden');
assert(master_product_simple_status(['stock'=>5,'price'=>10,'active'=>1,'sale_enabled'=>1,'restricted'=>0,'catalog_scope'=>'master'])['key']==='visible');
```

- [ ] **Step 2: Run and verify failure**

Run: `php -d zend.assertions=1 -d assert.exception=1 tests/product_simple_status_test.php`
Expected: FAIL with undefined function.

- [ ] **Step 3: Implement status derivation from existing eligibility**

Return `out_of_stock` first when stock is zero, `hidden` when manually hidden/restricted/invalid price, otherwise `visible`. Do not add a second stored status column.

- [ ] **Step 4: Add a field-allowlisted endpoint**

Allow only `price`, `stock`, `min_stock`, `hidden_from_store`; require admin CSRF; validate numeric ranges; use `WHERE id=? AND updated_at=?`; return HTTP 409 on a stale row.

- [ ] **Step 5: Render inline controls and save one cell at a time**

Use debounced price/stock inputs, an explicit visibility button, disabled saving state, inline success/error, and refresh the row status from the server response.

- [ ] **Step 6: Run tests and syntax checks**

Run: `php tests/product_simple_status_test.php && node tests/product_quick_edit_test.cjs && php -l api/admin_product_quick_update.php && node --check assets/js/app.js`
Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
git add includes/master_catalog.php api/admin_product_quick_update.php admin/todos_productos.php assets/js/app.js assets/css/styles.css tests/product_simple_status_test.php tests/product_quick_edit_test.cjs
git commit -m "feat: simplify product status and quick editing"
```

### Task 2: Bandeja de pendientes e inicio operativo

**Files:**
- Create: `includes/admin_actions.php`
- Modify: `admin/index.php`
- Modify: `assets/css/styles.css`
- Create: `tests/admin_actions_test.php`
- Modify: `tests/admin_dashboard_11604_test.php`

**Interfaces:**
- Produces: `admin_action_counts(PDO $pdo): array`.
- Produces: `admin_action_items(array $counts): array<int,array{key,label,count,priority,href}>`.

- [ ] **Step 1: Write failing priority tests**

```php
$items=admin_action_items(['pending_payments'=>2,'new_orders'=>1,'low_stock'=>8,'missing_images'=>3]);
assert($items[0]['key']==='pending_payments');
assert($items[0]['priority']==='urgent');
assert(array_column($items,'key')===['pending_payments','new_orders','low_stock','missing_images']);
```

- [ ] **Step 2: Run and verify failure**

Run: `php -d zend.assertions=1 -d assert.exception=1 tests/admin_actions_test.php`
Expected: FAIL because the module does not exist.

- [ ] **Step 3: Implement independent safe counts**

Count pending payments/orders, low stock, missing/invalid price, missing image, and nutrition review. Catch a missing optional nutrition table and return zero only for that count; never hide failures from core order queries.

- [ ] **Step 4: Replace decorative dashboard sections**

Keep sales today, pending orders, payments to review and restock count; add the action list and three quick links. Remove advanced charts from the main view without deleting their code or advanced page.

- [ ] **Step 5: Run dashboard tests**

Run: `php tests/admin_actions_test.php && php tests/admin_dashboard_11604_test.php`
Expected: PASS with empty and populated fixtures.

- [ ] **Step 6: Commit**

```bash
git add includes/admin_actions.php admin/index.php assets/css/styles.css tests/admin_actions_test.php tests/admin_dashboard_11604_test.php
git commit -m "feat: add prioritized admin action inbox"
```

### Task 3: Asistente de combos

**Files:**
- Create: `includes/combo_builder.php`
- Modify: `admin/combos.php`
- Create: `api/admin_combo_quote.php`
- Modify: `assets/js/app.js`
- Modify: `assets/css/styles.css`
- Create: `tests/combo_builder_test.php`
- Create: `tests/combo_builder_ui_test.cjs`

**Interfaces:**
- Produces: `combo_builder_normalize_items(array $items): array`.
- Produces: `combo_builder_quote(array $products, array $items): array{cost:float,max_stock:int,items:array}`.
- Endpoint returns quote only from current database rows.

- [ ] **Step 1: Write failing calculation tests**

```php
$quote=combo_builder_quote([
  1=>['stock'=>10,'cost_price'=>2,'restricted'=>0],
  2=>['stock'=>5,'cost_price'=>1,'restricted'=>0],
],[['id'=>1,'quantity'=>2],['id'=>1,'quantity'=>1],['id'=>2,'quantity'=>1]]);
assert($quote['max_stock']===3);
assert($quote['cost']===7.0);
```

- [ ] **Step 2: Run and verify failure**

Run: `php -d zend.assertions=1 -d assert.exception=1 tests/combo_builder_test.php`
Expected: FAIL with undefined functions.

- [ ] **Step 3: Implement normalization and server quote**

Merge repeated IDs, reject quantities outside 1–999, reject missing/restricted/unpublished products, calculate cost from `cost_price` and maximum buildable stock using integer division.

- [ ] **Step 4: Build the three-step UI**

Step 1 search/select products; Step 2 quantities, cost, suggested price and capacity; Step 3 name, final price, image, featured and publish. Back/Continue preserves selection; final POST uses the existing combo transaction after recalculating the quote.

- [ ] **Step 5: Add stale-stock and empty-combo tests**

The API quote may become stale; the final save must reload rows and reject a now-impossible combo. An empty or all-invalid item array returns validation error.

- [ ] **Step 6: Run tests and checks**

Run: `php tests/combo_builder_test.php && node tests/combo_builder_ui_test.cjs && php -l api/admin_combo_quote.php && php -l admin/combos.php`
Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
git add includes/combo_builder.php admin/combos.php api/admin_combo_quote.php assets/js/app.js assets/css/styles.css tests/combo_builder_test.php tests/combo_builder_ui_test.cjs
git commit -m "feat: add guided combo builder"
```

### Task 4: Integración y paquete final

**Files:**
- Modify: `README.md`
- Modify: `MEJORAS_DISENO_Y_CATALOGO.md`
- Test: all files under `tests/`

**Interfaces:**
- Consumes all prior nutrition, checkout and admin interfaces.
- Produces a clean user-facing ZIP under the configured outputs directory.

- [ ] **Step 1: Update installation and migration instructions**

Document the nutrition and Plin migrations, required PHP extensions, optional Open Food Facts connectivity, and safe behavior when external nutrition lookup is unavailable.

- [ ] **Step 2: Run all PHP tests**

Run: `for test in tests/*.php; do php -d zend.assertions=1 -d assert.exception=1 "$test" || exit 1; done`
Expected: all unit/static tests PASS; optional database integration may report SKIP only when its documented environment variables are absent.

- [ ] **Step 3: Run all JavaScript tests**

Run: `for test in tests/*.cjs; do node "$test" || exit 1; done`
Expected: all PASS.

- [ ] **Step 4: Run syntax, secret and artifact checks**

Run: `find . -name '*.php' -not -path './vendor/*' -print0 | xargs -0 -n1 php -l`
Expected: no syntax errors. Then run existing documentation/security/deliverable tests and confirm payment receipts and local configuration secrets are excluded from the archive.

- [ ] **Step 5: Build and test the archive**

Create `outputs/stockflow_nutricion_checkout_admin.zip` from the project while excluding `.git`, local config, receipts and temporary files; run `unzip -t` and expect no errors.

- [ ] **Step 6: Commit documentation and verification evidence**

```bash
git add README.md MEJORAS_DISENO_Y_CATALOGO.md
git commit -m "docs: explain nutrition checkout and admin workflows"
```

