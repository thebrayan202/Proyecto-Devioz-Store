<?php
declare(strict_types=1);

require_once __DIR__ . '/../includes/master_catalog.php';

function csrf_token(): string
{
    return $_SESSION['csrf_token'] ??= 'test-csrf-secret';
}

$ids = master_bulk_selection(['ids' => ['2', '2', '9', '-1', 'x']]);
if ($ids !== [2, 9]) throw new RuntimeException('IDs');

if (master_product_publication_fields(false, false) !== ['active' => 1, 'sale_enabled' => 1]) {
    throw new RuntimeException('Un producto permitido debe quedar disponible automáticamente.');
}
if (master_product_publication_fields(true, false) !== ['active' => 1, 'sale_enabled' => 0]) {
    throw new RuntimeException('Ocultar debe prevalecer aunque exista stock.');
}
if (master_product_publication_fields(false, true) !== ['active' => 0, 'sale_enabled' => 0]) {
    throw new RuntimeException('Un producto restringido nunca debe publicarse.');
}
if (master_product_is_manually_hidden(['sale_enabled' => 0, 'stock' => 0])) {
    throw new RuntimeException('Un importado sin stock no debe parecer ocultado manualmente.');
}
if (!master_product_is_manually_hidden(['sale_enabled' => 0, 'stock' => 4])) {
    throw new RuntimeException('Un producto con stock retirado de venta debe conservar el control Ocultar.');
}

master_bulk_assert_changes_effective([
    ['active' => 1, 'sale_enabled' => 1],
    ['active' => 0, 'sale_enabled' => 0],
], ['active' => 1, 'sale_enabled' => 1]);
if (master_bulk_row_needs_changes(['active' => 1, 'sale_enabled' => 1], ['active' => 1, 'sale_enabled' => 1])) {
    throw new RuntimeException('Una fila idéntica no debe actualizarse.');
}
if (!master_bulk_row_needs_changes(['active' => 0, 'sale_enabled' => 0], ['active' => 1, 'sale_enabled' => 1])) {
    throw new RuntimeException('Una fila distinta debe actualizarse.');
}
$allAlreadyUpdatedRejected = false;
try {
    master_bulk_assert_changes_effective([
        ['active' => 1, 'sale_enabled' => 1],
        ['active' => 1, 'sale_enabled' => 1],
    ], ['active' => 1, 'sale_enabled' => 1]);
} catch (RuntimeException) {
    $allAlreadyUpdatedRejected = true;
}
if (!$allAlreadyUpdatedRejected) throw new RuntimeException('Una acción totalmente repetida debe rechazarse.');

$changes = master_bulk_changes([
    'active' => '1',
    'sale_enabled' => '1',
    'margin_pct' => '30',
    'min_stock' => '5',
]);
if ($changes !== ['active' => 1, 'sale_enabled' => 1, 'margin_pct' => 30.0, 'min_stock' => 5]) {
    throw new RuntimeException('Cambios');
}

$invalidMarginRejected = false;
try {
    master_bulk_changes(['margin_pct' => '900']);
} catch (InvalidArgumentException) {
    $invalidMarginRejected = true;
}
if (!$invalidMarginRejected) throw new RuntimeException('Debió fallar');

if (master_bulk_money_cents('12.340') !== '12.34') throw new RuntimeException('Centavos exactos');
if (master_bulk_money_cents('0.005') !== '0.01') throw new RuntimeException('Redondeo medio');
if (master_bulk_money_cents('0.004') !== '0.00') throw new RuntimeException('Redondeo inferior');
foreach (['0.001', '0.004'] as $tinyPrice) {
    $tinyPriceRejected = false;
    try {
        master_bulk_changes(['price' => $tinyPrice]);
    } catch (InvalidArgumentException) {
        $tinyPriceRejected = true;
    }
    if (!$tinyPriceRejected) throw new RuntimeException('Precio positivo redondeado a cero');
}
$roundedPriceChanges = master_bulk_changes(['price' => '0.005']);
if ($roundedPriceChanges !== ['price' => '0.01']) throw new RuntimeException('Precio canónico');
if (master_bulk_confirmation_token([2], ['price' => '0.005'], 1000, str_repeat('r', 48), 'test-secret')
    !== master_bulk_confirmation_token([2], ['price' => '0.01'], 1000, str_repeat('r', 48), 'test-secret')) {
    throw new RuntimeException('Token no canónico');
}
$publishChanges = ['active' => 1, 'sale_enabled' => 1, 'price' => '0.01'];
if (!master_bulk_publish_eligible(['active' => 0, 'sale_enabled' => 0, 'restricted' => 0, 'stock' => 1, 'cost_price' => '0.01', 'price' => '0.00'], $publishChanges)) {
    throw new RuntimeException('Publicación canónica');
}
if (!master_bulk_publish_eligible(['active' => 0, 'sale_enabled' => 0, 'restricted' => 0, 'stock' => 0, 'cost_price' => '0.00', 'price' => '0.00'], ['active' => 1, 'sale_enabled' => 1])) {
    throw new RuntimeException('Mostrar en automático debe aceptar stock cero; seguirá oculto hasta reponerlo.');
}
$guard = master_bulk_publish_guard(['active' => 1, 'sale_enabled' => 1, 'price' => '0.005']);
if (!str_contains($guard['sql'], 'restricted = 0') || str_contains($guard['sql'], 'cost_price > 0') || $guard['params'] !== [1, 1]) {
    throw new RuntimeException('Guardia de publicación canónica');
}

$tokenIds = [2, 9];
$tokenChanges = ['active' => 1, 'sale_enabled' => 1];
$expiresAt = 1000;
$nonce = str_repeat('a', 48);
$token = master_bulk_confirmation_token($tokenIds, $tokenChanges, $expiresAt, $nonce, 'test-secret');
if (!master_bulk_confirmation_is_valid($token, $tokenIds, $tokenChanges, $expiresAt, $nonce, 999, 'test-secret')) {
    throw new RuntimeException('Token válido');
}
if (master_bulk_confirmation_is_valid($token, [2, 10], $tokenChanges, $expiresAt, $nonce, 999, 'test-secret')) {
    throw new RuntimeException('Token no vinculó IDs');
}
if (master_bulk_confirmation_is_valid($token, $tokenIds, ['active' => 0, 'sale_enabled' => 1], $expiresAt, $nonce, 999, 'test-secret')) {
    throw new RuntimeException('Token no vinculó cambios');
}
if (master_bulk_confirmation_is_valid($token, $tokenIds, $tokenChanges, $expiresAt, $nonce, 1000, 'test-secret')) {
    throw new RuntimeException('Token vencido');
}
if (master_bulk_confirmation_is_valid($token . 'x', $tokenIds, $tokenChanges, $expiresAt, $nonce, 999, 'test-secret')) {
    throw new RuntimeException('Token alterado');
}

$_SESSION = [];
$oneTimeToken = master_bulk_store_confirmation($tokenIds, $tokenChanges);
$loadedConfirmation = master_bulk_load_confirmation($oneTimeToken);
if ($loadedConfirmation['ids'] !== $tokenIds) throw new RuntimeException('Carga de token');
$replayRejected = false;
try {
    master_bulk_load_confirmation($oneTimeToken);
} catch (RuntimeException) {
    $replayRejected = true;
}
if (!$replayRejected) throw new RuntimeException('Token reutilizable');

$expiredNonce = str_repeat('b', 48);
$expiredAt = time() - 1;
$_SESSION['master_bulk_confirmation'] = [
    'token' => master_bulk_confirmation_token($tokenIds, $tokenChanges, $expiredAt, $expiredNonce, csrf_token()),
    'nonce' => $expiredNonce,
    'ids' => $tokenIds,
    'changes' => $tokenChanges,
    'expires_at' => $expiredAt,
];
$expiredRejected = false;
try {
    master_bulk_load_confirmation($_SESSION['master_bulk_confirmation']['token']);
} catch (RuntimeException) {
    $expiredRejected = true;
}
if (!$expiredRejected) throw new RuntimeException('Token vencido aceptado');
if (isset($_SESSION['master_bulk_confirmation'])) throw new RuntimeException('Token vencido no consumido');

$route = file_get_contents(__DIR__ . '/../admin/productos_masivo.php');
foreach ([
    'verify_csrf()',
    'require_admin()',
    'master_bulk_apply(db(), $confirmation[\'ids\'], $confirmation[\'changes\']',
] as $needle) {
    if (!str_contains($route, $needle)) throw new RuntimeException('Falta control: ' . $needle);
}

$contract = file_get_contents(__DIR__ . '/../includes/master_catalog.php');
foreach ([
    "catalog_scope = 'master' AND id IN", 'margin_pct, min_stock', 'FOR UPDATE',
    'array_chunk($ids, 500)', '$statement->rowCount()', 'master_bulk_publish_guard',
    'master_bulk_assert_changes_effective', '$pdo->beginTransaction()', '$pdo->rollBack()',
    'INSERT INTO activity_log', 'master_bulk_assert_publishable',
    "unset(\$_SESSION['master_bulk_confirmation'])",
] as $needle) {
    if (!str_contains($contract, $needle)) throw new RuntimeException('Falta contrato: ' . $needle);
}
if (!(strpos($contract, '$pdo->beginTransaction()') < strpos($contract, 'master_bulk_master_rows($pdo, $ids, true)')
    && strpos($contract, 'INSERT INTO activity_log') < strpos($contract, '$pdo->commit()')
    && strpos($contract, '$pdo->rollBack()') > strpos($contract, '$pdo->beginTransaction()'))) {
    throw new RuntimeException('Transacción o auditoría fuera de orden');
}

echo "master_catalog_actions_test: OK\n";
