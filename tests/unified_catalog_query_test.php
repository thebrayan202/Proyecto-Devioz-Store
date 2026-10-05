<?php
declare(strict_types=1);
require_once __DIR__ . '/../includes/unified_catalog.php';
$result = unified_catalog_where(unified_catalog_filters([
    'q' => 'arroz', 'source' => 'Tottus', 'category' => 'Abarrotes',
    'availability' => 'available', 'min_price' => '2', 'max_price' => '20',
]));
foreach (['name LIKE :q_name', 'source_name = :source', 'category = :category', 'available = 1', 'cost >= :min_price', 'cost <= :max_price'] as $fragment) {
    if (!str_contains($result['sql'], $fragment)) throw new RuntimeException('Falta filtro: ' . $fragment);
}
if ($result['params']['q_name'] !== '%arroz%') throw new RuntimeException('Búsqueda incorrecta');
echo "unified_catalog_query_test: OK\n";
