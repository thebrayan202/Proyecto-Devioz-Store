<?php
declare(strict_types=1);

$storefront = file_get_contents(__DIR__ . '/../includes/storefront.php');
assert(is_string($storefront));
assert(str_contains($storefront, 'LEFT JOIN product_nutrition'));
assert(str_contains($storefront, 'nutrition_status'));
assert(str_contains($storefront, 'kcal_serving'));

echo "nutrition_public_flow_test OK\n";
