# Nutrición verificable Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Añadir fichas nutricionales trazables y cálculos de calorías al catálogo, carrito y asistente sin inventar valores faltantes.

**Architecture:** Una tabla local por producto es la única fuente pública. Un módulo PHP puro clasifica y calcula; las consultas externas solo precargan datos desde administración y nunca se ejecutan durante una compra. El asistente recibe resultados calculados, no genera nutrientes.

**Tech Stack:** PHP 8+, PDO MySQL/MariaDB, JavaScript sin framework, Open Food Facts HTTP API, SQL idempotente.

**Spec:** `docs/superpowers/specs/2026-09-25-nutricion-y-checkout-dinamico-design.md`

## Global Constraints

- Solo alimentos para consumo humano participan en cálculos.
- Cada cifra conserva fuente, confianza y fecha; cero no significa dato ausente.
- Datos de etiqueta verificados nunca se sobrescriben automáticamente.
- Sin dato confiable se muestra “Sin información”; la IA no estima calorías.
- La tienda pública no depende de una API externa para funcionar.

## Review Focus

- Peso desconocido: mostrar dato por porción o 100 g, nunca total del envase.
- Categorías ambiguas: quedar en revisión y fuera del total hasta confirmación.
- Producto para mascotas: marcar `non_food` aunque su nombre diga “alimento”.
- Respuesta externa incompleta: guardar solo campos válidos sin convertir ausencias en cero.
- Carrito mixto: sumar lo conocido y mostrar cobertura exacta.

---

### Task 1: Esquema nutricional y funciones puras

**Files:**
- Create: `database/upgrade_nutrition.sql`
- Create: `includes/nutrition.php`
- Create: `tests/nutrition_test.php`
- Modify: `database/stockflow.sql`
- Modify: `database/upgrade_suite_completa.sql`

**Interfaces:**
- Produces: `nutrition_default_applicability(string $name, string $category): string`
- Produces: `nutrition_normalize(array $row): array`
- Produces: `nutrition_calculate(array $nutrition, ?float $packageAmount, string $packageUnit, int $quantity): array`
- Produces: `nutrition_summarize(array $items): array`

- [ ] **Step 1: Write the failing unit test**

```php
$pet = nutrition_default_applicability('Alimento para perro 1 kg', 'Mascotas');
assert($pet === 'non_food');
$summary = nutrition_summarize([
    ['quantity'=>2,'nutrition'=>['applicability'=>'food','energy_kcal_serving'=>120]],
    ['quantity'=>1,'nutrition'=>['applicability'=>'food','energy_kcal_serving'=>null]],
]);
assert($summary === ['known_kcal'=>240.0,'known_items'=>1,'unknown_items'=>1,'total_items'=>2]);
```

- [ ] **Step 2: Run the test and verify failure**

Run: `php -d zend.assertions=1 -d assert.exception=1 tests/nutrition_test.php`
Expected: FAIL because `includes/nutrition.php` does not exist.

- [ ] **Step 3: Add the idempotent table**

```sql
CREATE TABLE IF NOT EXISTS product_nutrition (
  product_id INT UNSIGNED NOT NULL PRIMARY KEY,
  applicability ENUM('food','non_food','review') NOT NULL DEFAULT 'review',
  energy_kcal_100g DECIMAL(10,2) NULL,
  serving_size DECIMAL(10,2) NULL,
  serving_unit ENUM('g','ml','unit') NULL,
  energy_kcal_serving DECIMAL(10,2) NULL,
  protein_g DECIMAL(10,2) NULL,
  carbohydrate_g DECIMAL(10,2) NULL,
  fat_g DECIMAL(10,2) NULL,
  source_type ENUM('label','open_food_facts','ins','usda','manual') NULL,
  source_ref VARCHAR(255) NULL,
  confidence ENUM('verified','reference') NULL,
  verified_at DATETIME NULL,
  verified_by INT UNSIGNED NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_product_nutrition_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
);
```

- [ ] **Step 4: Implement strict normalization and calculations**

```php
function nutrition_summarize(array $items): array {
    $known=0.0; $knownItems=0; $unknown=0;
    foreach ($items as $item) {
        $value=$item['nutrition']['energy_kcal_serving']??null;
        if (($item['nutrition']['applicability']??'review')!=='food' || $value===null) {$unknown++; continue;}
        $known += round((float)$value * max(1,(int)($item['quantity']??1)),2); $knownItems++;
    }
    return ['known_kcal'=>round($known,2),'known_items'=>$knownItems,'unknown_items'=>$unknown,'total_items'=>count($items)];
}
```

- [ ] **Step 5: Run nutrition and schema tests**

Run: `php -d zend.assertions=1 -d assert.exception=1 tests/nutrition_test.php && php tests/master_catalog_migration_test.php`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add database/upgrade_nutrition.sql database/stockflow.sql database/upgrade_suite_completa.sql includes/nutrition.php tests/nutrition_test.php
git commit -m "feat: add traceable nutrition model"
```

### Task 2: Edición administrativa y consulta por EAN

**Files:**
- Create: `includes/nutrition_lookup.php`
- Create: `api/product_nutrition_lookup.php`
- Create: `tests/nutrition_lookup_test.php`
- Modify: `admin/producto_form.php`
- Modify: `admin/producto_guardar.php`
- Modify: `assets/js/app.js`
- Modify: `assets/css/styles.css`

**Interfaces:**
- Consumes: `nutrition_normalize(array): array`
- Produces: `nutrition_lookup_open_food_facts(string $ean, array $config): array`
- Produces endpoint JSON: `{success, match, message}` with CSRF and admin authorization.

- [ ] **Step 1: Write tests for external payload and overwrite protection**

```php
$parsed=nutrition_parse_open_food_facts(['status'=>1,'product'=>['code'=>'7751234567890','nutriments'=>['energy-kcal_100g'=>150]]]);
assert($parsed['energy_kcal_100g']===150.0);
assert(nutrition_can_replace(['source_type'=>'label','confidence'=>'verified'],$parsed)===false);
assert(nutrition_parse_open_food_facts(['status'=>0])===[]);
```

- [ ] **Step 2: Run and verify failure**

Run: `php -d zend.assertions=1 -d assert.exception=1 tests/nutrition_lookup_test.php`
Expected: FAIL with undefined lookup functions.

- [ ] **Step 3: Implement the admin-only lookup boundary**

```php
function nutrition_lookup_open_food_facts(string $ean,array $config):array {
    if (!preg_match('/^(?:\d{8}|\d{12,14})$/D',$ean)) throw new InvalidArgumentException('EAN inválido.');
    return nutrition_http_json('https://world.openfoodfacts.org/api/v2/product/'.rawurlencode($ean).'?fields=code,product_name,brands,serving_size,nutriments', $config);
}
```

Endpoint requirements: `require_role('admin')`, POST only, CSRF, 5-second timeout, 256 KB response cap, one request per second per session, and no API response written directly to HTML.

- [ ] **Step 4: Add the product form fields and explicit preview**

Use radio/select values `food`, `non_food`, `review`; nullable numeric inputs with `min="0"`; source and confidence read-only summary; a “Buscar por EAN” button that fills a preview and a separate “Usar estos datos” action.

- [ ] **Step 5: Persist with an upsert inside the product transaction**

```sql
INSERT INTO product_nutrition (...) VALUES (...)
ON DUPLICATE KEY UPDATE applicability=VALUES(applicability), energy_kcal_100g=VALUES(energy_kcal_100g), updated_at=CURRENT_TIMESTAMP
```

Reject non-finite or negative numbers and reject `verified` unless the source is `label` or the administrator explicitly confirms the record.

- [ ] **Step 6: Run tests and syntax checks**

Run: `php tests/nutrition_lookup_test.php && php -l api/product_nutrition_lookup.php && php -l admin/producto_guardar.php && node --check assets/js/app.js`
Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
git add includes/nutrition_lookup.php api/product_nutrition_lookup.php admin/producto_form.php admin/producto_guardar.php assets/js/app.js assets/css/styles.css tests/nutrition_lookup_test.php
git commit -m "feat: manage verified product nutrition"
```

### Task 3: Calorías en catálogo, carrito y asistente

**Files:**
- Modify: `includes/storefront.php`
- Modify: `api/productos.php`
- Modify: `api/cart_reconcile.php`
- Modify: `includes/shopping_sources.php`
- Modify: `includes/shopping_agent.php`
- Modify: `includes/shopping_ai.php`
- Modify: `asistente_compras.php`
- Modify: `assets/js/app.js`
- Modify: `assets/js/shopping_chat.js`
- Create: `tests/nutrition_public_flow_test.php`
- Create: `tests/nutrition_public_ui_test.cjs`

**Interfaces:**
- Consumes: `nutrition_calculate()` and `nutrition_summarize()`.
- Produces public fields: `nutrition_status`, `kcal_serving`, `nutrition_basis`.
- Produces cart/assistant summary: `{known_kcal, known_items, unknown_items, total_items}`.

- [ ] **Step 1: Add failing public-flow tests**

Assert that SQL uses `LEFT JOIN product_nutrition`, non-food rows expose `nutrition_status=no_aplica`, missing food data exposes `sin_informacion`, and AI prompt fields contain only validated numeric nutrition values.

- [ ] **Step 2: Run and verify failure**

Run: `php tests/nutrition_public_flow_test.php && node tests/nutrition_public_ui_test.cjs`
Expected: FAIL because nutrition output is absent.

- [ ] **Step 3: Extend public queries without changing sale eligibility**

```sql
LEFT JOIN product_nutrition n ON n.product_id=p.id
```

Return only normalized display fields. Never expose `verified_by` or raw external payloads.

- [ ] **Step 4: Recalculate summaries after cart and AI selection**

The assistant must select product IDs first, reload them from the database, then call `nutrition_summarize`. The cart endpoint must calculate after reconciliation so removed or quantity-limited items cannot contribute calories.

- [ ] **Step 5: Render coverage-aware copy**

```js
const nutritionText = n.total_items
  ? `Calorías conocidas: ${Math.round(n.known_kcal)} kcal · ${n.known_items} de ${n.total_items} productos con información.`
  : 'Sin información nutricional aplicable.';
```

- [ ] **Step 6: Run focused and regression suites**

Run: `php tests/nutrition_public_flow_test.php && node tests/nutrition_public_ui_test.cjs && php tests/shopping_agent_test.php && node tests/ai_recommendations_boundaries_test.cjs`
Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
git add includes/storefront.php api/productos.php api/cart_reconcile.php includes/shopping_sources.php includes/shopping_agent.php includes/shopping_ai.php asistente_compras.php assets/js/app.js assets/js/shopping_chat.js tests/nutrition_public_flow_test.php tests/nutrition_public_ui_test.cjs
git commit -m "feat: show reliable calories in shopping flows"
```

