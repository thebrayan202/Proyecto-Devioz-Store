<?php
declare(strict_types=1);

require_once __DIR__ . '/../includes/culqi.php';

assert(culqi_config(['CULQI_PUBLIC_KEY' => '', 'CULQI_PRIVATE_KEY' => ''])['enabled'] === false);
$cfg = culqi_config(['CULQI_PUBLIC_KEY' => 'pk_test_123456', 'CULQI_PRIVATE_KEY' => 'sk_test_abcdef', 'CULQI_MODE' => 'test']);
assert($cfg['enabled'] === true);
assert(isset($cfg['public_key']));
assert(!isset($cfg['private_key_public']));

assert(culqi_verify_charge(['amount' => 1250, 'currency_code' => 'PEN', 'outcome' => ['type' => 'venta_exitosa'], 'reference_code' => 'ORD-1'], ['amount' => 12.50, 'currency' => 'PEN', 'reference' => 'ORD-1']) === true);
assert(culqi_verify_charge(['amount' => 1200, 'currency_code' => 'PEN', 'outcome' => ['type' => 'venta_exitosa'], 'reference_code' => 'ORD-1'], ['amount' => 12.50, 'currency' => 'PEN', 'reference' => 'ORD-1']) === false);
assert(culqi_verify_charge(['amount' => 1250, 'currency_code' => 'USD', 'outcome' => ['type' => 'venta_exitosa'], 'reference_code' => 'ORD-1'], ['amount' => 12.50, 'currency' => 'PEN', 'reference' => 'ORD-1']) === false);
assert(culqi_webhook_seen(['evt_1'], 'evt_1') === true);
assert(culqi_webhook_seen(['evt_1'], 'evt_2') === false);

echo "culqi_payment_test OK\n";
