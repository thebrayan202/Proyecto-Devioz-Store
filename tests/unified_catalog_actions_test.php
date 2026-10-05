<?php
declare(strict_types=1);
require_once __DIR__ . '/../includes/unified_catalog.php';
if (validate_margin('25') !== 25.0) throw new RuntimeException('Margen válido');
foreach (['-1', '501', 'abc'] as $invalid) {
    try { validate_margin($invalid); throw new RuntimeException('Debió fallar'); }
    catch (InvalidArgumentException) {}
}
if (validate_money('12.34') !== 12.34) throw new RuntimeException('Precio válido');
if (validate_money('', true) !== null) throw new RuntimeException('Precio vacío anulable');
$key = parse_item_key('external:125');
if ($key !== ['source_type' => 'external', 'source_id' => 125]) throw new RuntimeException('Clave externa');
echo "unified_catalog_actions_test: OK\n";
