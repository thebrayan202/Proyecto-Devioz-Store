<?php
declare(strict_types=1);

require_once __DIR__ . '/../includes/functions.php';

assert(payment_method_available('efectivo', []) === true);
assert(payment_method_available('plin', ['plin' => ['enabled' => true, 'phone' => '999999999', 'qr' => '']]) === true);
assert(payment_method_available('plin', ['plin' => ['enabled' => true, 'phone' => '', 'qr' => '']]) === false);
assert(payment_method_available('yape', ['yape' => ['enabled' => true, 'phone' => '', 'qr' => 'assets/uploads/payments/yape.png']]) === true);
assert(payment_method_available('tarjeta', []) === false);

echo "payment_methods_test OK\n";
