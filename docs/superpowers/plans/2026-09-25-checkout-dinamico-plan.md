# Checkout dinámico Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convertir el pago actual en un recorrido de cuatro pasos, añadir Plin y cobrar tarjetas mediante Culqi sin debilitar la validación transaccional existente.

**Architecture:** La interfaz usa una máquina de estados pequeña; el servidor continúa siendo autoridad para catálogo, stock, cupones, entrega y total. Yape y Plin comparten el flujo seguro de comprobantes, con configuración y etiquetas separadas.

**Tech Stack:** PHP 8+, PDO MySQL/MariaDB, JavaScript y CSS sin framework, carga de imágenes existente.

**Spec:** `docs/superpowers/specs/2026-09-25-nutricion-y-checkout-dinamico-design.md`

## Global Constraints

- Pasos: revisión, entrega, pago y confirmación.
- Métodos reales: efectivo, Yape, Plin y tarjeta mediante Culqi cuando esté configurado.
- Cada avance valida el paso; la creación vuelve a validar todo en el servidor.
- Método sin configurar no aparece ni se acepta por manipulación del navegador.
- Los errores conservan datos válidos y el foco vuelve al campo o paso afectado.

## Review Focus

- Total cambia tras un cupón o una cantidad: invalidar confirmación y recotizar.
- Yape o Plin sin QR ni número: ocultar el método y rechazarlo en servidor.
- Doble clic en confirmar: crear un solo pedido.
- Retroceso entre pasos: conservar campos no sensibles y limpiar comprobantes incompatibles al cambiar de método.
- Error de stock final: volver al resumen con la línea identificada.

---

### Task 1: Configuración y modelo de Plin

**Files:**
- Create: `database/upgrade_plin_checkout.sql`
- Modify: `database/stockflow.sql`
- Modify: `database/upgrade_suite_completa.sql`
- Modify: `includes/functions.php`
- Modify: `admin/datos_empresa.php`
- Create: `tests/payment_methods_test.php`

**Interfaces:**
- Produces: `payment_settings(): array{yape:array,plin:array}`.
- Produces: `payment_method_available(string $method, array $settings): bool`.

- [ ] **Step 1: Write failing payment-method tests**

```php
assert(payment_method_available('efectivo',[])===true);
assert(payment_method_available('plin',['plin'=>['enabled'=>true,'phone'=>'999999999','qr'=>'']])===true);
assert(payment_method_available('plin',['plin'=>['enabled'=>true,'phone'=>'','qr'=>'']])===false);
assert(payment_method_available('tarjeta',[])===false);
```

- [ ] **Step 2: Run and verify failure**

Run: `php -d zend.assertions=1 -d assert.exception=1 tests/payment_methods_test.php`
Expected: FAIL with undefined function.

- [ ] **Step 3: Add settings and expand the order enum idempotently**

```sql
INSERT IGNORE INTO store_settings(setting_key,setting_value) VALUES
('plin_enabled','0'),('plin_phone',''),('plin_owner',''),('plin_qr','');
ALTER TABLE yape_orders MODIFY metodo_pago ENUM('yape','plin','efectivo') NOT NULL DEFAULT 'efectivo';
```

- [ ] **Step 4: Add configuration fields and helpers**

Keep Yape compatibility, add Plin fields with the same image validation, and return only public account values needed by checkout.

- [ ] **Step 5: Run tests and syntax checks**

Run: `php tests/payment_methods_test.php && php -l admin/datos_empresa.php && php -l includes/functions.php`
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add database/upgrade_plin_checkout.sql database/stockflow.sql database/upgrade_suite_completa.sql includes/functions.php admin/datos_empresa.php tests/payment_methods_test.php
git commit -m "feat: configure Plin payments"
```

### Task 2: Estructura accesible de cuatro pasos

**Files:**
- Modify: `includes/public_cart.php`
- Create: `assets/js/checkout_steps.js`
- Modify: `assets/css/styles.css`
- Create: `tests/checkout_steps_test.cjs`

**Interfaces:**
- Produces: `window.DeviozCheckoutSteps.create({steps,onChange})`.
- Emits: `checkout:stepchange` with `{step,index}`.

- [ ] **Step 1: Write failing state-machine tests**

```js
const flow=createCheckoutSteps(['review','delivery','payment','confirmation']);
assert.equal(flow.current(),'review');
assert.equal(flow.next(()=>false),false);
assert.equal(flow.current(),'review');
assert.equal(flow.next(()=>true),true);
assert.equal(flow.current(),'delivery');
```

- [ ] **Step 2: Run and verify failure**

Run: `node tests/checkout_steps_test.cjs`
Expected: FAIL because the module is missing.

- [ ] **Step 3: Implement the state machine as a focused module**

```js
function createCheckoutSteps(names){let index=0;return{current:()=>names[index],go:i=>{if(i<0||i>=names.length)return false;index=i;return true;},next:validate=>validate()&&index<names.length-1?(index++,true):false,back:()=>index>0?(index--,true):false};}
```

- [ ] **Step 4: Split the modal markup into four panels**

Each panel uses `data-checkout-step`, headings, progress list with `aria-current="step"`, and Back/Continue buttons. Only confirmation contains the final order button.

- [ ] **Step 5: Add responsive CSS and focus movement**

At widths below 700 px use one column, sticky action footer and scrollable content; on step change focus the step heading. Hidden panels use `hidden`, not opacity alone.

- [ ] **Step 6: Run tests and checks**

Run: `node tests/checkout_steps_test.cjs && node --check assets/js/checkout_steps.js && php -l includes/public_cart.php`
Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
git add includes/public_cart.php assets/js/checkout_steps.js assets/css/styles.css tests/checkout_steps_test.cjs
git commit -m "feat: add guided checkout steps"
```

### Task 3: Integrar cotización, métodos y confirmación

**Files:**
- Modify: `assets/js/app.js`
- Modify: `includes/public_cart.php`
- Modify: `api/checkout_quote.php`
- Modify: `api/yape_order.php`
- Modify: `includes/receipt_ticket.php`
- Modify: `includes/receipt_layout.php`
- Create: `tests/checkout_dynamic_test.cjs`
- Create: `tests/plin_order_test.php`

**Interfaces:**
- Consumes: `DeviozCheckoutSteps`, `payment_settings`, `payment_method_available`.
- Produces order methods exactly `efectivo`, `yape`, `plin`.

- [ ] **Step 1: Write failing UI and server boundary tests**

Test that changing cart/zone/coupon clears the final-ready state, only configured methods render, Plin requires an image, efectivo never requires one, and `tarjeta` returns validation error.

- [ ] **Step 2: Run and verify failure**

Run: `node tests/checkout_dynamic_test.cjs && php tests/plin_order_test.php`
Expected: FAIL because the step integration and Plin branch are absent.

- [ ] **Step 3: Replace the select with method cards**

```html
<button type="button" data-payment-method="efectivo">Efectivo</button>
<button type="button" data-payment-method="yape">Yape</button>
<button type="button" data-payment-method="plin">Plin</button>
```

Render only configured digital methods and maintain a hidden input as the single submitted value.

- [ ] **Step 4: Connect step validation to existing quote state**

Review requires a reconciled nonempty cart; delivery requires customer, phone, valid quote and address when applicable; payment requires method-specific values; confirmation requires unchanged cart fingerprint and quote.

- [ ] **Step 5: Generalize receipt handling without lowering limits**

Reuse JPEG/PNG/WEBP, 5 MB input cap and client optimization. When the method changes between Yape and Plin, clear the selected file and preview to prevent a mislabeled receipt.

- [ ] **Step 6: Enforce method availability in `api/yape_order.php`**

```php
if (!in_array($paymentMethod,['efectivo','yape','plin'],true) || !payment_method_available($paymentMethod,payment_settings())) {
    throw new InvalidArgumentException('Método de pago no disponible.');
}
```

Use the existing transaction, reservation, snapshot and duplicate-submit protections.

- [ ] **Step 7: Update receipt labels and tracking copy**

Use `payment_label($method)` everywhere; do not infer every non-cash method is Yape.

- [ ] **Step 8: Run focused and regression tests**

Run: `node tests/checkout_dynamic_test.cjs && php tests/plin_order_test.php && node tests/yape_order_snapshot_integrity_test.cjs && php tests/public_cart_allocation_test.php`
Expected: all tests PASS.

- [ ] **Step 9: Commit**

```bash
git add assets/js/app.js includes/public_cart.php api/checkout_quote.php api/yape_order.php includes/receipt_ticket.php includes/receipt_layout.php tests/checkout_dynamic_test.cjs tests/plin_order_test.php
git commit -m "feat: complete dynamic cash Yape and Plin checkout"
```

### Task 4: Tarjeta con Culqi y webhook idempotente

**Files:**
- Create: `includes/culqi.php`
- Create: `api/culqi_charge.php`
- Create: `api/culqi_webhook.php`
- Modify: `includes/public_cart.php`
- Modify: `assets/js/app.js`
- Modify: `database/upgrade_plin_checkout.sql`
- Create: `tests/culqi_payment_test.php`
- Create: `tests/culqi_checkout_ui_test.cjs`

**Interfaces:**
- Produces: `culqi_config(): array` with public key only in public payloads.
- Produces: `culqi_verify_charge(array $charge, array $expected): bool`.
- Produces endpoints that never accept amount or approval state as authoritative client input.

- [ ] **Step 1: Write failing verification and UI tests**

Test disabled configuration, amount/currency/reference mismatch, approved and declined charges, repeated webhook IDs, absence of private keys in HTML, and reset of final-ready state after a card error.

- [ ] **Step 2: Run and verify failure**

Run: `php tests/culqi_payment_test.php && node tests/culqi_checkout_ui_test.cjs`
Expected: FAIL because the Culqi boundary does not exist.

- [ ] **Step 3: Add local/environment configuration**

Read `CULQI_PUBLIC_KEY`, `CULQI_PRIVATE_KEY`, `CULQI_WEBHOOK_SECRET` and `CULQI_MODE`; require matching test/live key prefixes; expose only enabled flag and public key to the browser.

- [ ] **Step 4: Tokenize in Culqi Checkout and charge on the server**

Load `https://js.culqi.com/checkout-js` only when enabled. Submit the token plus the server-issued quote/order reference. The backend reloads order total and customer email, then creates the charge using the private key.

- [ ] **Step 5: Implement webhook verification and idempotency**

Store provider event/charge IDs with unique indexes. Validate the configured signature/secret and re-read the charge from Culqi before changing local state. Repeated notifications return success without repeating inventory movements.

- [ ] **Step 6: Run focused and payment regression tests**

Run: `php tests/culqi_payment_test.php && node tests/culqi_checkout_ui_test.cjs && php tests/plin_order_test.php && node tests/yape_order_snapshot_integrity_test.cjs`
Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
git add includes/culqi.php api/culqi_charge.php api/culqi_webhook.php includes/public_cart.php assets/js/app.js database/upgrade_plin_checkout.sql tests/culqi_payment_test.php tests/culqi_checkout_ui_test.cjs
git commit -m "feat: add verified Culqi card payments"
```
