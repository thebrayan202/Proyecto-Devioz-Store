<?php
$sql=file_get_contents(__DIR__.'/../database/upgrade_catalogo_maestro_11604.sql');
$fresh=file_get_contents(__DIR__.'/../database/stockflow.sql');
$executable=preg_replace('/--[^\n]*/', '', $sql);
if($executable===null || $fresh===false) throw new RuntimeException('No se pudo leer SQL');
foreach(['catalog_migrations','legacy_products','source_product_id','sale_enabled','restricted','UNIQUE KEY uq_products_source','catalog_migration_issues'] as $needle){
    if(!str_contains($executable,$needle)) throw new RuntimeException('Falta '.$needle);
}
foreach(['/MODIFY\s+COLUMN\s+name\s+VARCHAR\(255\)\s+NOT\s+NULL/i','/0\s+AS\s+stock/i','/0\s+AS\s+active/i','/0\s+AS\s+sale_enabled/i'] as $pattern){
    if(!preg_match($pattern,$executable)) throw new RuntimeException('SQL ejecutable seguro ausente: '.$pattern);
}
if(!preg_match('/name\s+VARCHAR\(255\)\s+NOT\s+NULL/i',$fresh)) throw new RuntimeException('Instalación nueva no admite nombres de origen');
if(str_contains($executable,'CHAR_LENGTH(producto)')) throw new RuntimeException('La migración omite nombres largos del catálogo fuente');
foreach(['catalog_migration_backups','INSERT IGNORE INTO legacy_products','INSERT IGNORE INTO legacy_product_images',"catalog_scope ENUM('legacy','master')","'master' AS catalog_scope","catalog_scope='master'",'Conteo de respaldo legacy no coincide'] as $needle){
    if(!str_contains($executable,$needle)) throw new RuntimeException('Coexistencia segura ausente: '.$needle);
}
foreach([
    '/IF\s+v_source_count\s*<>\s*11604\s+THEN/i',
    '/IF\s+v_valid_count\s*<>\s*11604\s+THEN/i',
    '/IF\s+v_imported_count\s*<>\s*11604\s+THEN/i',
    '/IF\s+v_missing_source_ids\s*<>\s*0\s+OR\s+v_extra_master_ids\s*<>\s*0\s+THEN/i',
] as $pattern){
    if(!preg_match($pattern,$executable)) throw new RuntimeException('Invariante exacta 11,604 ausente: '.$pattern);
}
foreach([
    '/SELECT\s+COUNT\(\*\)\s+INTO\s+v_missing_source_ids\s+FROM\s+productos\s+s\s+LEFT\s+JOIN\s+products\s+p[\s\S]*?p\.catalog_scope\s*=\s*\'master\'[\s\S]*?p\.source_product_id\s*=\s*s\.id_producto[\s\S]*?WHERE\s+p\.id\s+IS\s+NULL\s*;/i',
    '/SELECT\s+COUNT\(\*\)\s+INTO\s+v_extra_master_ids\s+FROM\s+products\s+p\s+LEFT\s+JOIN\s+productos\s+s[\s\S]*?s\.id_producto\s*=\s*p\.source_product_id[\s\S]*?WHERE\s+p\.catalog_scope\s*=\s*\'master\'[\s\S]*?s\.id_producto\s+IS\s+NULL\s*;/i',
] as $pattern){
    if(!preg_match($pattern,$executable)) throw new RuntimeException('Verificación del conjunto de IDs ausente: '.$pattern);
}
if(!preg_match('/IF\s+EXISTS\s*\(\s*SELECT\s+1\s+FROM\s+productos\s+s\s+INNER\s+JOIN\s+products\s+p[\s\S]*?p\.catalog_scope\s*=\s*\'legacy\'[\s\S]*?p\.source_product_id\s*=\s*s\.id_producto[\s\S]*?p\.code\s*=\s*CONCAT\(\'SRC-\',LPAD\(s\.id_producto,8,\'0\'\)\)[\s\S]*?\)\s+THEN/i',$executable)){
    throw new RuntimeException('Preflight de conflictos con filas legacy ausente');
}
$preflightPos=strpos($executable,"SET MESSAGE_TEXT='Conflicto de identidad con producto legacy'");
$masterInsertPos=strpos($executable,'INSERT IGNORE INTO products(');
if($preflightPos===false || $masterInsertPos===false || $preflightPos>$masterInsertPos) throw new RuntimeException('El preflight legacy debe ocurrir antes de importar');
if(!preg_match('/INSERT\s+IGNORE\s+INTO\s+products\s*\([\s\S]*?\)\s*SELECT[\s\S]*?FROM\s+productos[\s\S]*?;/i',$executable,$masterInsert)){
    throw new RuntimeException('La importación reintentable debe usar INSERT IGNORE');
}
if(preg_match('/ON\s+DUPLICATE\s+KEY\s+UPDATE/i',$masterInsert[0])) throw new RuntimeException('La importación no debe actualizar una fila en conflicto');
if(preg_match('/\b(?:UPDATE\s+`?products`?|REPLACE\s+INTO\s+`?products`?)\b/i',$executable)) throw new RuntimeException('Ruta de mutación de productos legacy detectada');
$ddlPos=strpos($executable,"CALL catalog_11604_prepare_legacy_table('stock_reservations','legacy_stock_reservations')");
$transactionPos=strpos($executable,'START TRANSACTION WITH CONSISTENT SNAPSHOT');
$backupPos=strpos($executable,'INSERT IGNORE INTO legacy_products');
$lastBackupPos=strpos($executable,'INSERT IGNORE INTO legacy_stock_reservations');
$commitPos=strpos($executable,'COMMIT;', $transactionPos===false ? 0 : $transactionPos);
if($ddlPos===false || $transactionPos===false || $backupPos===false || $lastBackupPos===false || $commitPos===false || !($ddlPos<$transactionPos && $transactionPos<$backupPos && $lastBackupPos<$commitPos)){
    throw new RuntimeException('El respaldo debe usar una sola instantánea transaccional después del DDL');
}
if(!preg_match('/IF\s+EXISTS\s*\([\s\S]*?information_schema\.tables[\s\S]*?legacy_stock_reservations[\s\S]*?UPPER\s*\(\s*COALESCE\s*\(\s*engine\s*,\s*\'\'\s*\)\s*\)\s*<>\s*\'INNODB\'[\s\S]*?\)\s+THEN/i',$executable)) throw new RuntimeException('Preflight InnoDB del respaldo ausente');
if(!preg_match('/IF\s+v_backup_txn\s*=\s*1\s+THEN\s+ROLLBACK\s*;/i',$executable)) throw new RuntimeException('Rollback del respaldo transaccional ausente');
if(preg_match('/CREATE\s+PROCEDURE\s+catalog_11604_run\(\)[\s\S]*?LOCK\s+TABLES/is',$executable)) throw new RuntimeException('LOCK TABLES prohibido dentro de rutina');
if(preg_match('/\b(?:DELETE\s+(?:FROM|[a-z_]+\s+FROM)|RENAME\s+TABLE|TRUNCATE\s+TABLE)\b/i',$executable)) throw new RuntimeException('La migración no debe cambiar la capa operativa previa');
if(!str_contains($fresh,"catalog_scope ENUM('legacy','master')")) throw new RuntimeException('Instalación nueva no tiene alcance de catálogo');
if(str_contains(strtoupper($executable),'TRUNCATE TABLE PRODUCTS')) throw new RuntimeException('Migración destructiva');
echo "master_catalog_migration_test: OK\n";
