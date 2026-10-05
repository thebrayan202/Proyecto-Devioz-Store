-- REPARACION ESPECIFICA DEL ERROR #1932 EN XAMPP / MARIADB
-- Reconstruye solamente las tablas auxiliares del catalogo comparador y la IA.
-- NO elimina productos, categorias, usuarios, pedidos, inventario ni movimientos.

CREATE DATABASE IF NOT EXISTS devioz_shop CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE devioz_shop;

SET @DEVIOZ_OLD_FOREIGN_KEY_CHECKS = @@FOREIGN_KEY_CHECKS;
SET FOREIGN_KEY_CHECKS = 0;

-- shopping_offers depende de shopping_sources: se elimina primero.
DROP TABLE IF EXISTS shopping_offers;
DROP TABLE IF EXISTS shopping_sources;
DROP TABLE IF EXISTS shopping_ai_usage;

SET FOREIGN_KEY_CHECKS = @DEVIOZ_OLD_FOREIGN_KEY_CHECKS;

-- A continuacion se recrean las tablas auxiliares y se completa la instalacion.
-- REPARACION SEGURA PARA LA INSTALACION ACTUAL
-- Selecciona la base correcta y agrega solo las estructuras faltantes.
CREATE DATABASE IF NOT EXISTS devioz_shop CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE devioz_shop;


-- ===== work/stockflow/database/upgrade_shopping_sources.sql =====
-- Ejecutar sobre la base de datos actual. No altera productos ni pedidos existentes.
CREATE TABLE IF NOT EXISTS shopping_sources (
 id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 slug VARCHAR(60) NOT NULL UNIQUE,
 name VARCHAR(100) NOT NULL,
 branch VARCHAR(120) NOT NULL DEFAULT '',
 active TINYINT(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE IF NOT EXISTS shopping_offers (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 source_id INT UNSIGNED NOT NULL,
 external_id VARCHAR(100) NOT NULL,
 gtin VARCHAR(14) NULL,
 name VARCHAR(180) NOT NULL,
 brand VARCHAR(150) NULL,
 category VARCHAR(80) NOT NULL,
 presentation VARCHAR(100) NOT NULL,
 price DECIMAL(10,2) NOT NULL,
 regular_price DECIMAL(10,2) NULL,
 discount_pct DECIMAL(10,2) NOT NULL DEFAULT 0.00,
 product_url TEXT NULL,
 image_url TEXT NULL,
 supermarket VARCHAR(100) NULL,
 stock INT UNSIGNED NULL,
 available TINYINT(1) NOT NULL DEFAULT 0,
 verified_at DATETIME NOT NULL,
 updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 UNIQUE KEY source_product (source_id, external_id),
 KEY offer_freshness (source_id, available, verified_at),
 KEY product_gtin (gtin),
 CONSTRAINT shopping_offer_source FOREIGN KEY(source_id) REFERENCES shopping_sources(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE IF NOT EXISTS shopping_ai_usage (
 usage_day DATE PRIMARY KEY,
 requests INT UNSIGNED NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
INSERT IGNORE INTO shopping_sources(slug,name,branch,active)
 VALUES ('plaza-vea','Plaza Vea','Pendiente de indicar sede o zona',1);


-- ===== work/stockflow/database/upgrade_suite_completa.sql =====
-- DEVIOZ STORE: clientes, favoritos, delivery, cupones, reservas, roles y auditoría.
-- Compatible con MariaDB 10.4+ / XAMPP. No elimina información existente.
USE devioz_shop;

ALTER TABLE shopping_offers
    ADD COLUMN IF NOT EXISTS brand VARCHAR(150) NULL AFTER name,
    ADD COLUMN IF NOT EXISTS regular_price DECIMAL(10,2) NULL AFTER price,
    ADD COLUMN IF NOT EXISTS discount_pct DECIMAL(10,2) NOT NULL DEFAULT 0.00 AFTER regular_price,
    ADD COLUMN IF NOT EXISTS product_url TEXT NULL AFTER discount_pct,
    ADD COLUMN IF NOT EXISTS image_url TEXT NULL AFTER product_url,
    ADD COLUMN IF NOT EXISTS supermarket VARCHAR(100) NULL AFTER image_url;

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS role ENUM('admin','inventario','caja','atencion') NOT NULL DEFAULT 'admin' AFTER password;

CREATE TABLE IF NOT EXISTS customers (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(120) NOT NULL,
    email VARCHAR(190) NOT NULL UNIQUE,
    phone VARCHAR(20) NOT NULL DEFAULT '',
    password VARCHAR(255) NOT NULL,
    active TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS customer_addresses (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    customer_id BIGINT UNSIGNED NOT NULL,
    label VARCHAR(60) NOT NULL DEFAULT 'Casa',
    district VARCHAR(100) NOT NULL,
    address VARCHAR(255) NOT NULL,
    reference VARCHAR(255) NULL,
    is_default TINYINT(1) NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_customer_address_customer FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,
    INDEX idx_customer_addresses_customer (customer_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS customer_favorites (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    customer_id BIGINT UNSIGNED NOT NULL,
    item_type ENUM('product','offer') NOT NULL,
    item_id BIGINT UNSIGNED NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY favorite_unique (customer_id, item_type, item_id),
    CONSTRAINT fk_customer_favorite_customer FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,
    INDEX idx_customer_favorites_customer (customer_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS delivery_zones (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    district VARCHAR(100) NOT NULL UNIQUE,
    delivery_fee DECIMAL(10,2) UNSIGNED NOT NULL DEFAULT 0.00,
    estimated_minutes SMALLINT UNSIGNED NOT NULL DEFAULT 45,
    active TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO delivery_zones (district, delivery_fee, estimated_minutes, active) VALUES
('Recojo en tienda', 0.00, 15, 1),
('Ate', 5.00, 45, 1),
('Santa Anita', 6.00, 50, 1),
('Lurigancho-Chosica', 8.00, 60, 1)
ON DUPLICATE KEY UPDATE delivery_fee=VALUES(delivery_fee), estimated_minutes=VALUES(estimated_minutes);

CREATE TABLE IF NOT EXISTS coupons (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(40) NOT NULL UNIQUE,
    description VARCHAR(160) NULL,
    discount_type ENUM('percent','fixed') NOT NULL,
    discount_value DECIMAL(10,2) UNSIGNED NOT NULL,
    minimum_amount DECIMAL(10,2) UNSIGNED NOT NULL DEFAULT 0.00,
    max_uses INT UNSIGNED NULL,
    used_count INT UNSIGNED NOT NULL DEFAULT 0,
    starts_at DATETIME NULL,
    ends_at DATETIME NULL,
    active TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS coupon_usage (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    coupon_id INT UNSIGNED NOT NULL,
    customer_id BIGINT UNSIGNED NULL,
    order_id BIGINT UNSIGNED NOT NULL,
    discount_amount DECIMAL(10,2) UNSIGNED NOT NULL,
    used_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY coupon_order_unique (coupon_id, order_id),
    CONSTRAINT fk_coupon_usage_coupon FOREIGN KEY (coupon_id) REFERENCES coupons(id),
    CONSTRAINT fk_coupon_usage_customer FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS stock_reservations (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    order_id BIGINT UNSIGNED NOT NULL,
    product_id INT UNSIGNED NOT NULL,
    quantity INT UNSIGNED NOT NULL,
    status ENUM('active','converted','released','expired') NOT NULL DEFAULT 'active',
    expires_at DATETIME NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY reservation_order_product (order_id, product_id),
    INDEX idx_stock_reservation_expiry (status, expires_at),
    CONSTRAINT fk_reservation_product FOREIGN KEY (product_id) REFERENCES products(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS activity_log (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    actor_type ENUM('admin','customer','system') NOT NULL,
    actor_id BIGINT UNSIGNED NULL,
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(60) NULL,
    entity_id BIGINT UNSIGNED NULL,
    details VARCHAR(500) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_activity_created (created_at),
    INDEX idx_activity_entity (entity_type, entity_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE yape_orders
    ADD COLUMN IF NOT EXISTS customer_id BIGINT UNSIGNED NULL AFTER id,
    ADD COLUMN IF NOT EXISTS subtotal_amount DECIMAL(10,2) UNSIGNED NOT NULL DEFAULT 0.00 AFTER expected_amount,
    ADD COLUMN IF NOT EXISTS delivery_zone_id INT UNSIGNED NULL AFTER tipo_despacho,
    ADD COLUMN IF NOT EXISTS delivery_address VARCHAR(255) NULL AFTER delivery_zone_id,
    ADD COLUMN IF NOT EXISTS delivery_reference VARCHAR(255) NULL AFTER delivery_address,
    ADD COLUMN IF NOT EXISTS delivery_fee DECIMAL(10,2) UNSIGNED NOT NULL DEFAULT 0.00 AFTER delivery_reference,
    ADD COLUMN IF NOT EXISTS coupon_id INT UNSIGNED NULL AFTER delivery_fee,
    ADD COLUMN IF NOT EXISTS coupon_code VARCHAR(40) NULL AFTER coupon_id,
    ADD COLUMN IF NOT EXISTS discount_amount DECIMAL(10,2) UNSIGNED NOT NULL DEFAULT 0.00 AFTER coupon_code,
    ADD COLUMN IF NOT EXISTS reserved_until DATETIME NULL AFTER fulfillment_status;

UPDATE yape_orders SET subtotal_amount = expected_amount WHERE subtotal_amount = 0.00;


-- ===== work/stockflow/database/integrar_catalogo_devioz.sql =====
-- Adaptador del catálogo devioz_shop para el asistente de compras.
-- Ejecutar después de crear las tablas de StockFlow. No elimina ni modifica
-- las tablas originales productos, categorias, supermercados, pedidos o detalle_pedido.

USE devioz_shop;

CREATE TABLE IF NOT EXISTS shopping_sources (
 id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 slug VARCHAR(60) NOT NULL UNIQUE,
 name VARCHAR(100) NOT NULL,
 branch VARCHAR(120) NOT NULL DEFAULT '',
 active TINYINT(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS shopping_offers (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 source_id INT UNSIGNED NOT NULL,
 external_id VARCHAR(100) NOT NULL,
 gtin VARCHAR(14) NULL,
 name VARCHAR(180) NOT NULL,
 brand VARCHAR(150) NULL,
 category VARCHAR(80) NOT NULL,
 presentation VARCHAR(100) NOT NULL,
 price DECIMAL(10,2) NOT NULL,
 regular_price DECIMAL(10,2) NULL,
 discount_pct DECIMAL(10,2) NOT NULL DEFAULT 0.00,
 product_url TEXT NULL,
 image_url TEXT NULL,
 supermarket VARCHAR(100) NULL,
 stock INT UNSIGNED NULL,
 available TINYINT(1) NOT NULL DEFAULT 0,
 verified_at DATETIME NOT NULL,
 updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 UNIQUE KEY source_product (source_id, external_id),
 KEY offer_freshness (source_id, available, verified_at),
 KEY product_gtin (gtin),
 CONSTRAINT shopping_offer_source FOREIGN KEY(source_id) REFERENCES shopping_sources(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS shopping_ai_usage (
 usage_day DATE PRIMARY KEY,
 requests INT UNSIGNED NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO shopping_sources (slug, name, branch, active)
SELECT
    CASE s.id_supermercado
        WHEN 1 THEN 'tottus'
        WHEN 2 THEN 'plaza-vea'
        WHEN 3 THEN 'metro'
        ELSE CONCAT('supermercado-', s.id_supermercado)
    END,
    LEFT(s.nombre, 100),
    'Catálogo importado',
    s.activo
FROM supermercados s
ON DUPLICATE KEY UPDATE
    name = VALUES(name),
    branch = VALUES(branch),
    active = VALUES(active);

INSERT INTO shopping_offers
    (source_id, external_id, gtin, name, brand, category, presentation, price, regular_price,
     discount_pct, product_url, image_url, supermarket, stock, available, verified_at)
SELECT
    ss.id,
    CAST(p.id_producto AS CHAR),
    CASE WHEN p.ean REGEXP '^[0-9]{8}$|^[0-9]{12}$|^[0-9]{13}$|^[0-9]{14}$' THEN p.ean ELSE NULL END,
    LEFT(p.producto, 180),
    LEFT(p.marca, 150),
    LEFT(TRIM(COALESCE(NULLIF(p.categoria,''),'Otros')),80),
    LEFT(COALESCE(NULLIF(p.presentacion, ''), NULLIF(p.unidad, ''), 'Unidad'), 100),
    p.precio_actual,
    p.precio_regular,
    p.descuento_pct,
    p.url_producto,
    p.imagen,
    p.supermercado,
    NULL,
    IF(p.activo = 1 AND UPPER(p.estado_disponibilidad) = 'DISPONIBLE', 1, 0),
    COALESCE(p.fecha_extraccion, p.fecha_carga, NOW())
FROM productos p
INNER JOIN shopping_sources ss
    ON ss.slug = CASE p.id_supermercado
        WHEN 1 THEN 'tottus'
        WHEN 2 THEN 'plaza-vea'
        WHEN 3 THEN 'metro'
        ELSE CONCAT('supermercado-', p.id_supermercado)
    END
WHERE p.precio_actual IS NOT NULL
  AND p.precio_actual > 0
  AND LOWER(COALESCE(p.categoria,'')) NOT REGEXP 'cerveza|vino|licor|tabaco|cigar|vape|cannabis'
  AND LOWER(p.producto) NOT REGEXP 'cerveza|vino|vodka|whisk|pisco|ron([^a-z]|$)|licor|cigar|tabaco|nicotin|vape|cannabis|energizante|energy|red bull|monster'
ON DUPLICATE KEY UPDATE
    gtin = VALUES(gtin),
    name = VALUES(name),
    brand = VALUES(brand),
    category = VALUES(category),
    presentation = VALUES(presentation),
    price = VALUES(price),
    regular_price = VALUES(regular_price),
    discount_pct = VALUES(discount_pct),
    product_url = VALUES(product_url),
    image_url = VALUES(image_url),
    supermarket = VALUES(supermarket),
    stock = VALUES(stock),
    available = VALUES(available),
    verified_at = VALUES(verified_at);

-- Incorpora automáticamente las categorías reales al administrador.
INSERT IGNORE INTO categories(name,icon,active)
SELECT DISTINCT LEFT(TRIM(p.categoria),80),UPPER(LEFT(TRIM(p.categoria),1)),1
FROM productos p
WHERE p.activo=1
  AND TRIM(COALESCE(p.categoria,''))<>''
  AND LOWER(COALESCE(p.categoria,'')) NOT REGEXP 'cerveza|vino|licor|tabaco|cigar|vape|cannabis'
  AND LOWER(p.producto) NOT REGEXP 'cerveza|vino|vodka|whisk|pisco|ron([^a-z]|$)|licor|cigar|tabaco|nicotin|vape|cannabis|energizante|energy|red bull|monster';

-- Yape order snapshots; equivalent to upgrade_yape_order_snapshots.sql.
ALTER TABLE yape_orders ADD COLUMN IF NOT EXISTS inventory_snapshot_version TINYINT UNSIGNED NOT NULL DEFAULT 0 AFTER reserved_until;
ALTER TABLE yape_order_items ADD COLUMN IF NOT EXISTS manual_combo_stock_reserved TINYINT(1) NULL AFTER units_per_item;
CREATE TABLE IF NOT EXISTS yape_order_item_components (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, order_item_id BIGINT UNSIGNED NOT NULL,
 product_id INT UNSIGNED NOT NULL, product_name VARCHAR(160) NOT NULL,
 units_per_combo SMALLINT UNSIGNED NOT NULL, reserved_units INT UNSIGNED NOT NULL,
 unit_cost DECIMAL(10,2) UNSIGNED NOT NULL DEFAULT 0.00, reference_unit_price DECIMAL(10,2) UNSIGNED NOT NULL DEFAULT 0.00,
 allocated_income DECIMAL(12,2) UNSIGNED NOT NULL DEFAULT 0.00, total_cost DECIMAL(12,2) UNSIGNED NOT NULL DEFAULT 0.00,
 profit DECIMAL(12,2) NOT NULL DEFAULT 0.00, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 UNIQUE KEY yape_order_item_component_unique (order_item_id, product_id), KEY idx_yape_order_item_components_product (product_id),
 CONSTRAINT fk_yape_order_item_components_item FOREIGN KEY (order_item_id) REFERENCES yape_order_items(id) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Only coherent legacy pending orders receive version 1. No component graph is
-- reconstructed from the mutable combo catalog.
UPDATE yape_orders o
SET inventory_snapshot_version = 1
WHERE o.status = 'pendiente'
  AND o.inventory_snapshot_version = 0
  AND NOT EXISTS (
      SELECT 1 FROM yape_order_items i
      WHERE i.order_id = o.id AND i.stock_after IS NULL
  )
  AND COALESCE((SELECT SUM(r.quantity) FROM stock_reservations r
      WHERE r.order_id = o.id AND r.status = 'active'), 0) > 0
  AND COALESCE((SELECT SUM(r.quantity) FROM stock_reservations r
      WHERE r.order_id = o.id AND r.status = 'active'), 0)
      = COALESCE((SELECT SUM(m.units_changed) FROM inventory_movements m
      WHERE m.reference = o.order_code AND m.payment_method = 'yape'), 0);

-- Operational report: version 0 remains untouched and must be reconciled by an
-- administrator before any approval, rejection, or expiry can mutate stock.
SELECT id, order_code, status
FROM yape_orders
WHERE status = 'pendiente' AND inventory_snapshot_version = 0;
