-- Catálogo maestro 11,604, MariaDB 10.4+.
-- Coexistence migration: it only appends master rows and legacy snapshots.

CREATE TABLE IF NOT EXISTS catalog_migrations (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  migration_key VARCHAR(80) NOT NULL UNIQUE,
  source_count INT UNSIGNED NOT NULL,
  imported_count INT UNSIGNED NOT NULL DEFAULT 0,
  status ENUM('running','completed','failed') NOT NULL,
  phase VARCHAR(40) NOT NULL DEFAULT 'backup',
  details TEXT NULL,
  started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  completed_at DATETIME NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE catalog_migrations ADD COLUMN IF NOT EXISTS phase VARCHAR(40) NOT NULL DEFAULT 'backup' AFTER status;

CREATE TABLE IF NOT EXISTS catalog_migration_backups (
  migration_key VARCHAR(80) NOT NULL,
  table_name VARCHAR(64) NOT NULL,
  source_count BIGINT UNSIGNED NOT NULL,
  legacy_count BIGINT UNSIGNED NOT NULL,
  snapshot_verified_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY(migration_key,table_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS catalog_migration_issues (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  migration_key VARCHAR(80) NOT NULL,
  source_product_id INT NOT NULL DEFAULT 0,
  issue_code VARCHAR(80) NOT NULL,
  details VARCHAR(500) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_catalog_migration_issue(migration_key,source_product_id,issue_code),
  INDEX idx_catalog_migration_issues_key(migration_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE products
  MODIFY COLUMN name VARCHAR(255) NOT NULL,
  ADD COLUMN IF NOT EXISTS catalog_scope ENUM('legacy','master') NOT NULL DEFAULT 'legacy',
  ADD COLUMN IF NOT EXISTS source_product_id INT NULL,
  ADD COLUMN IF NOT EXISTS source_name VARCHAR(100) NOT NULL DEFAULT 'Devioz',
  ADD COLUMN IF NOT EXISTS ean VARCHAR(100) NULL,
  ADD COLUMN IF NOT EXISTS brand VARCHAR(150) NULL,
  ADD COLUMN IF NOT EXISTS presentation VARCHAR(150) NULL,
  ADD COLUMN IF NOT EXISTS supplier_price DECIMAL(10,2) NULL,
  ADD COLUMN IF NOT EXISTS suggested_price DECIMAL(10,2) NULL,
  ADD COLUMN IF NOT EXISTS margin_pct DECIMAL(7,2) NULL,
  ADD COLUMN IF NOT EXISTS sale_enabled TINYINT(1) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS restricted TINYINT(1) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS source_updated_at DATETIME NULL;

DELIMITER //

DROP PROCEDURE IF EXISTS catalog_11604_ensure_products_indexes//
CREATE PROCEDURE catalog_11604_ensure_products_indexes()
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.statistics WHERE table_schema=DATABASE() AND table_name='products' AND index_name='uq_products_source') THEN
    ALTER TABLE products ADD UNIQUE KEY uq_products_source(source_product_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.statistics WHERE table_schema=DATABASE() AND table_name='products' AND index_name='idx_products_public') THEN
    ALTER TABLE products ADD INDEX idx_products_public(active,sale_enabled,restricted,stock,price);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.statistics WHERE table_schema=DATABASE() AND table_name='products' AND index_name='idx_products_source_category') THEN
    ALTER TABLE products ADD INDEX idx_products_source_category(source_name,category);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.statistics WHERE table_schema=DATABASE() AND table_name='products' AND index_name='idx_products_ean') THEN
    ALTER TABLE products ADD INDEX idx_products_ean(ean);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.statistics WHERE table_schema=DATABASE() AND table_name='products' AND index_name='idx_products_scope') THEN
    ALTER TABLE products ADD INDEX idx_products_scope(catalog_scope,active,sale_enabled);
  END IF;
END//

-- Each snapshot table is a read-only copy. DDL is finished before all seven
-- copies are taken from one consistent InnoDB snapshot; originals are read only.
DROP PROCEDURE IF EXISTS catalog_11604_prepare_legacy_table//
CREATE PROCEDURE catalog_11604_prepare_legacy_table(IN p_table VARCHAR(64), IN p_legacy VARCHAR(64))
BEGIN
  DECLARE v_exists INT DEFAULT 0;
  SELECT COUNT(*) INTO v_exists FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name=p_table;
  IF v_exists=0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Falta tabla dependiente requerida para respaldo'; END IF;
  SET @catalog_11604_sql=CONCAT('CREATE TABLE IF NOT EXISTS `',p_legacy,'` LIKE `',p_table,'`');
  PREPARE catalog_11604_stmt FROM @catalog_11604_sql;
  EXECUTE catalog_11604_stmt;
  DEALLOCATE PREPARE catalog_11604_stmt;
END//

DROP PROCEDURE IF EXISTS catalog_11604_run//
CREATE PROCEDURE catalog_11604_run()
run_catalog: BEGIN
  DECLARE v_phase VARCHAR(40) DEFAULT 'backup';
  DECLARE v_source_count INT UNSIGNED DEFAULT 0;
  DECLARE v_valid_count INT UNSIGNED DEFAULT 0;
  DECLARE v_imported_count INT UNSIGNED DEFAULT 0;
  DECLARE v_missing_source_ids INT UNSIGNED DEFAULT 0;
  DECLARE v_extra_master_ids INT UNSIGNED DEFAULT 0;
  DECLARE v_backup_txn TINYINT(1) DEFAULT 0;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    IF v_backup_txn=1 THEN
      ROLLBACK;
      SET v_backup_txn=0;
    END IF;
    UPDATE catalog_migrations SET status='failed',completed_at=NULL,details=CONCAT('failed in ',v_phase,'; ',COALESCE(details,'')) WHERE migration_key='catalogo_maestro_11604';
    RESIGNAL;
  END;
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name='productos') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Falta la tabla fuente productos';
  END IF;
  INSERT INTO catalog_migrations(migration_key,source_count,imported_count,status,phase,details)
  VALUES('catalogo_maestro_11604',0,0,'running','backup','Inicio de coexistencia')
  ON DUPLICATE KEY UPDATE status=IF(status='completed','completed','running'),completed_at=IF(status='completed',completed_at,NULL);
  SELECT phase INTO v_phase FROM catalog_migrations WHERE migration_key='catalogo_maestro_11604';
  IF v_phase='completed' THEN LEAVE run_catalog; END IF;

  IF v_phase='backup' THEN
    CALL catalog_11604_prepare_legacy_table('products','legacy_products');
    CALL catalog_11604_prepare_legacy_table('product_images','legacy_product_images');
    CALL catalog_11604_prepare_legacy_table('inventory_movements','legacy_inventory_movements');
    CALL catalog_11604_prepare_legacy_table('combos','legacy_combos');
    CALL catalog_11604_prepare_legacy_table('combo_items','legacy_combo_items');
    CALL catalog_11604_prepare_legacy_table('store_featured_products','legacy_store_featured_products');
    CALL catalog_11604_prepare_legacy_table('stock_reservations','legacy_stock_reservations');

    IF EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_schema=DATABASE()
        AND table_name IN (
          'products','product_images','inventory_movements','combos','combo_items','store_featured_products','stock_reservations',
          'legacy_products','legacy_product_images','legacy_inventory_movements','legacy_combos','legacy_combo_items','legacy_store_featured_products','legacy_stock_reservations'
        )
        AND UPPER(COALESCE(engine,''))<>'INNODB'
    ) THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='El respaldo consistente requiere tablas InnoDB';
    END IF;

    SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
    START TRANSACTION WITH CONSISTENT SNAPSHOT;
    SET v_backup_txn=1;

    INSERT IGNORE INTO legacy_products SELECT p.* FROM products p WHERE p.catalog_scope='legacy';
    INSERT IGNORE INTO legacy_product_images SELECT pi.* FROM product_images pi INNER JOIN products p ON p.id=pi.product_id AND p.catalog_scope='legacy';
    INSERT IGNORE INTO legacy_inventory_movements SELECT m.* FROM inventory_movements m INNER JOIN products p ON p.id=m.product_id AND p.catalog_scope='legacy';
    INSERT IGNORE INTO legacy_combos SELECT * FROM combos;
    INSERT IGNORE INTO legacy_combo_items SELECT * FROM combo_items;
    INSERT IGNORE INTO legacy_store_featured_products SELECT f.* FROM store_featured_products f INNER JOIN products p ON p.id=f.product_id AND p.catalog_scope='legacy';
    INSERT IGNORE INTO legacy_stock_reservations SELECT r.* FROM stock_reservations r INNER JOIN products p ON p.id=r.product_id AND p.catalog_scope='legacy';

    IF (SELECT COUNT(*) FROM legacy_products)<>(SELECT COUNT(*) FROM products WHERE catalog_scope='legacy')
      OR (SELECT COUNT(*) FROM legacy_product_images)<>(SELECT COUNT(*) FROM product_images pi INNER JOIN products p ON p.id=pi.product_id AND p.catalog_scope='legacy')
      OR (SELECT COUNT(*) FROM legacy_inventory_movements)<>(SELECT COUNT(*) FROM inventory_movements m INNER JOIN products p ON p.id=m.product_id AND p.catalog_scope='legacy')
      OR (SELECT COUNT(*) FROM legacy_combos)<>(SELECT COUNT(*) FROM combos)
      OR (SELECT COUNT(*) FROM legacy_combo_items)<>(SELECT COUNT(*) FROM combo_items)
      OR (SELECT COUNT(*) FROM legacy_store_featured_products)<>(SELECT COUNT(*) FROM store_featured_products f INNER JOIN products p ON p.id=f.product_id AND p.catalog_scope='legacy')
      OR (SELECT COUNT(*) FROM legacy_stock_reservations)<>(SELECT COUNT(*) FROM stock_reservations r INNER JOIN products p ON p.id=r.product_id AND p.catalog_scope='legacy') THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Conteo de respaldo legacy no coincide';
    END IF;

    INSERT INTO catalog_migration_backups(migration_key,table_name,source_count,legacy_count) VALUES
      ('catalogo_maestro_11604','legacy_products',(SELECT COUNT(*) FROM products WHERE catalog_scope='legacy'),(SELECT COUNT(*) FROM legacy_products)),
      ('catalogo_maestro_11604','legacy_product_images',(SELECT COUNT(*) FROM product_images pi INNER JOIN products p ON p.id=pi.product_id AND p.catalog_scope='legacy'),(SELECT COUNT(*) FROM legacy_product_images)),
      ('catalogo_maestro_11604','legacy_inventory_movements',(SELECT COUNT(*) FROM inventory_movements m INNER JOIN products p ON p.id=m.product_id AND p.catalog_scope='legacy'),(SELECT COUNT(*) FROM legacy_inventory_movements)),
      ('catalogo_maestro_11604','legacy_combos',(SELECT COUNT(*) FROM combos),(SELECT COUNT(*) FROM legacy_combos)),
      ('catalogo_maestro_11604','legacy_combo_items',(SELECT COUNT(*) FROM combo_items),(SELECT COUNT(*) FROM legacy_combo_items)),
      ('catalogo_maestro_11604','legacy_store_featured_products',(SELECT COUNT(*) FROM store_featured_products f INNER JOIN products p ON p.id=f.product_id AND p.catalog_scope='legacy'),(SELECT COUNT(*) FROM legacy_store_featured_products)),
      ('catalogo_maestro_11604','legacy_stock_reservations',(SELECT COUNT(*) FROM stock_reservations r INNER JOIN products p ON p.id=r.product_id AND p.catalog_scope='legacy'),(SELECT COUNT(*) FROM legacy_stock_reservations))
    ON DUPLICATE KEY UPDATE source_count=VALUES(source_count),legacy_count=VALUES(legacy_count),snapshot_verified_at=CURRENT_TIMESTAMP;
    UPDATE catalog_migrations SET phase='importing',details='Legacy snapshots verified; coexistence import pending' WHERE migration_key='catalogo_maestro_11604';
    COMMIT;
    SET v_backup_txn=0;
    SET v_phase='importing';
  END IF;

  SELECT COUNT(*) INTO v_source_count FROM productos;
  IF v_source_count<>11604 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='La fuente debe contener exactamente 11604 fichas'; END IF;
  INSERT IGNORE INTO catalog_migration_issues(migration_key,source_product_id,issue_code,details)
  SELECT 'catalogo_maestro_11604',COALESCE(id_producto,0),'invalid_required_fields','id_producto, categoría u origen fuera de límites'
  FROM productos WHERE id_producto IS NULL OR id_producto<=0 OR CHAR_LENGTH(COALESCE(categoria,''))>80 OR CHAR_LENGTH(COALESCE(supermercado,''))>100;
  SELECT COUNT(*) INTO v_valid_count FROM productos WHERE id_producto>0 AND CHAR_LENGTH(COALESCE(categoria,''))<=80 AND CHAR_LENGTH(COALESCE(supermercado,''))<=100;
  IF v_valid_count<>11604 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='La fuente debe contener exactamente 11604 fichas válidas'; END IF;

  IF EXISTS (
    SELECT 1
    FROM productos s
    INNER JOIN products p
      ON p.catalog_scope='legacy'
     AND (p.source_product_id=s.id_producto OR p.code=CONCAT('SRC-',LPAD(s.id_producto,8,'0')))
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Conflicto de identidad con producto legacy';
  END IF;

  INSERT IGNORE INTO products(code,name,category,description,cost_price,price,stock,min_stock,image_url,featured,entrega_inmediata,active,catalog_scope,source_product_id,source_name,ean,brand,presentation,supplier_price,suggested_price,margin_pct,sale_enabled,restricted,source_updated_at)
  SELECT CONCAT('SRC-',LPAD(id_producto,8,'0')),producto,COALESCE(NULLIF(TRIM(categoria),''),'Sin categoría'),NULL,
    0.00 AS cost_price,0.00 AS price,0 AS stock,5 AS min_stock,NULLIF(LEFT(imagen,500),''),
    0 AS featured,0 AS entrega_inmediata,0 AS active,'master' AS catalog_scope,id_producto,COALESCE(NULLIF(TRIM(supermercado),''),'Devioz'),
    NULLIF(TRIM(ean),''),NULLIF(LEFT(TRIM(marca),150),''),NULLIF(LEFT(COALESCE(NULLIF(TRIM(presentacion),''),TRIM(unidad)),150),''),
    precio_actual,CASE WHEN precio_actual>0 THEN ROUND(precio_actual*1.25,2) ELSE NULL END,NULL,
    0 AS sale_enabled,0 AS restricted,COALESCE(fecha_extraccion,fecha_carga)
  FROM productos WHERE id_producto>0 AND CHAR_LENGTH(COALESCE(categoria,''))<=80 AND CHAR_LENGTH(COALESCE(supermercado,''))<=100;

  SELECT COUNT(*) INTO v_imported_count FROM products WHERE catalog_scope='master';
  SELECT COUNT(*) INTO v_missing_source_ids
  FROM productos s
  LEFT JOIN products p
    ON p.catalog_scope='master'
   AND p.source_product_id=s.id_producto
   AND p.code=CONCAT('SRC-',LPAD(s.id_producto,8,'0'))
  WHERE p.id IS NULL;
  SELECT COUNT(*) INTO v_extra_master_ids
  FROM products p
  LEFT JOIN productos s ON s.id_producto=p.source_product_id
  WHERE p.catalog_scope='master' AND s.id_producto IS NULL;

  IF v_imported_count<>11604 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Deben existir exactamente 11604 productos master'; END IF;
  IF v_missing_source_ids<>0 OR v_extra_master_ids<>0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='El conjunto de IDs master no coincide exactamente con la fuente'; END IF;
  UPDATE catalog_migrations SET source_count=v_source_count,imported_count=v_imported_count,status='completed',phase='completed',details='coexistence_verified; source=11604; valid=11604; master=11604; missing=0; extra=0',completed_at=CURRENT_TIMESTAMP WHERE migration_key='catalogo_maestro_11604';
END//

CALL catalog_11604_ensure_products_indexes()//
CALL catalog_11604_run()//
DROP PROCEDURE catalog_11604_run//
DROP PROCEDURE catalog_11604_prepare_legacy_table//
DROP PROCEDURE catalog_11604_ensure_products_indexes//
DELIMITER ;
