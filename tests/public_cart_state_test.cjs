const assert = require('node:assert/strict');
const state = require('../assets/js/public_cart_state.js');

const staleRestrictedProduct = {
    kind: 'product', id: 8, quantity: 1, name: 'stale', price: 0.01, restricted: true,
};
const staleRestrictedCombo = {
    kind: 'combo', id: 15, quantity: 1, name: 'old combo', price: 0.01,
};

assert.deepEqual(state.cartRequestItems([staleRestrictedProduct, staleRestrictedCombo]), [
    { type: 'product', id: 8, quantity: 1 },
    { type: 'combo', id: 15, quantity: 1 },
]);
assert.deepEqual(
    state.reconcileVerifiedCart({ success: true, items: [] }),
    [],
    'a stale restricted product omitted by the endpoint must not hydrate the cart'
);
assert.deepEqual(
    state.reconcileVerifiedCart({ success: true, items: [] }),
    [],
    'a combo omitted because a component is restricted must not hydrate the cart'
);

const tampered = {
    kind: 'product', id: 4, quantity: 2, name: 'tampered', price: 0.01, image_url: 'https://invalid.test/item',
};
assert.deepEqual(state.cartRequestItems([tampered]), [
    { type: 'product', id: 4, quantity: 2 },
], 'the request must not preserve browser-provided names, prices, or images');
const canonical = {
    type: 'product', kind: 'product', id: 4, quantity: 2, code: 'P-004', name: 'canonical', category: 'Snacks',
    description: 'canonical description', price: 4.5, stock: 6, image_url: '/assets/canonical.png', icon: 'S',
    presentation: 'unidad', presentation_label: 'Unidad', units_per_item: 1, restricted: false,
};
assert.deepEqual(state.reconcileVerifiedCart({ success: true, items: [canonical] }), [canonical]);
assert.notEqual(state.reconcileVerifiedCart({ success: true, items: [canonical] })[0].name, tampered.name);
assert.notEqual(state.reconcileVerifiedCart({ success: true, items: [canonical] })[0].price, tampered.price);
assert.deepEqual(
    state.reconcileVerifiedCart({ success: true, items: [{ ...canonical, restricted: true }] }),
    [],
    'a non-canonical restricted response item must be removed as a client-side defense'
);
assert.deepEqual(state.reconcileVerifiedCart({ success: false, items: [canonical] }), []);
assert.deepEqual(state.reconcileVerifiedCart(null), []);

console.log('public cart state reconciliation: OK');
