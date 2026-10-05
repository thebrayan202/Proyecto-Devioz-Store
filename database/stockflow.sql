-- DEVIOZ STORE / STOCKFLOW - BASE DE DATOS UNIFICADA
-- Compatible con MariaDB 10.4+ (XAMPP y la mayoria de hostings).
-- Sirve para una instalacion nueva y para actualizar la version anterior.
-- No elimina productos, usuarios ni movimientos existentes.

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

CREATE DATABASE IF NOT EXISTS devioz_shop
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE devioz_shop;

CREATE TABLE IF NOT EXISTS users (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    username VARCHAR(80) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS login_attempts (
    fingerprint CHAR(64) PRIMARY KEY,
    attempts SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    locked_until DATETIME NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_login_attempts_cleanup (updated_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS categories (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(80) NOT NULL UNIQUE,
    icon VARCHAR(12) NOT NULL DEFAULT 'D',
    active TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS products (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(20) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    category VARCHAR(80) NOT NULL,
    description VARCHAR(1000) NULL,
    cost_price DECIMAL(10,2) UNSIGNED NOT NULL DEFAULT 0.00,
    price DECIMAL(10,2) UNSIGNED NOT NULL DEFAULT 0.00,
    stock INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Stock en unidades individuales',
    min_stock INT UNSIGNED NOT NULL DEFAULT 5,
    units_per_pack SMALLINT UNSIGNED NOT NULL DEFAULT 1,
    pack_price DECIMAL(10,2) UNSIGNED NULL,
    image_url VARCHAR(500) NULL,
    featured TINYINT(1) NOT NULL DEFAULT 0,
    entrega_inmediata TINYINT(1) NOT NULL DEFAULT 1,
    active TINYINT(1) NOT NULL DEFAULT 1,
    catalog_scope ENUM('legacy','master') NOT NULL DEFAULT 'legacy',
    source_product_id INT NULL,
    source_name VARCHAR(100) NOT NULL DEFAULT 'Devioz',
    ean VARCHAR(100) NULL,
    brand VARCHAR(150) NULL,
    presentation VARCHAR(150) NULL,
    supplier_price DECIMAL(10,2) NULL,
    suggested_price DECIMAL(10,2) NULL,
    margin_pct DECIMAL(7,2) NULL,
    sale_enabled TINYINT(1) NOT NULL DEFAULT 0,
    restricted TINYINT(1) NOT NULL DEFAULT 0,
    source_updated_at DATETIME NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_products_name (name),
    INDEX idx_products_category (category),
    INDEX idx_products_active (active),
    INDEX idx_products_featured (featured),
    INDEX idx_products_stock (stock),
    UNIQUE KEY uq_products_source (source_product_id),
    INDEX idx_products_public (active,sale_enabled,restricted,stock,price),
    INDEX idx_products_source_category (source_name,category),
    INDEX idx_products_ean (ean),
    INDEX idx_products_scope (catalog_scope,active,sale_enabled)
) ENGINE=InnoDB;

-- Si products ya existia, agrega solamente las columnas nuevas.
ALTER TABLE products
    MODIFY COLUMN name VARCHAR(255) NOT NULL,
    ADD COLUMN IF NOT EXISTS cost_price DECIMAL(10,2) UNSIGNED NOT NULL DEFAULT 0.00 AFTER description,
    ADD COLUMN IF NOT EXISTS units_per_pack SMALLINT UNSIGNED NOT NULL DEFAULT 1 AFTER min_stock,
    ADD COLUMN IF NOT EXISTS pack_price DECIMAL(10,2) UNSIGNED NULL AFTER units_per_pack,
    ADD COLUMN IF NOT EXISTS featured TINYINT(1) NOT NULL DEFAULT 0 AFTER image_url,
    ADD COLUMN IF NOT EXISTS entrega_inmediata TINYINT(1) NOT NULL DEFAULT 1 AFTER featured,
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

CREATE UNIQUE INDEX IF NOT EXISTS uq_products_source ON products (source_product_id);
CREATE INDEX IF NOT EXISTS idx_products_public ON products (active,sale_enabled,restricted,stock,price);
CREATE INDEX IF NOT EXISTS idx_products_source_category ON products (source_name,category);
CREATE INDEX IF NOT EXISTS idx_products_ean ON products (ean);
CREATE INDEX IF NOT EXISTS idx_products_scope ON products (catalog_scope,active,sale_enabled);

CREATE TABLE IF NOT EXISTS product_images (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    product_id INT UNSIGNED NOT NULL,
    image_url VARCHAR(500) NOT NULL,
    sort_order SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_product_images_product FOREIGN KEY (product_id) REFERENCES products(id) ON UPDATE CASCADE ON DELETE CASCADE,
    INDEX idx_product_images_product_order (product_id, sort_order)
) ENGINE=InnoDB;

-- Respaldo de imágenes para servidores donde Apache no puede escribir en assets/uploads.
CREATE TABLE IF NOT EXISTS uploaded_media (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    mime_type VARCHAR(30) NOT NULL,
    original_name VARCHAR(255) NULL,
    file_size INT UNSIGNED NOT NULL,
    image_data MEDIUMBLOB NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Configuración pública de la tienda y métodos de pago.
CREATE TABLE IF NOT EXISTS store_settings (
    setting_key VARCHAR(80) PRIMARY KEY,
    setting_value TEXT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

INSERT IGNORE INTO store_settings (setting_key, setting_value) VALUES
('yape_enabled', '1'),
('yape_phone', ''),
('yape_owner', 'Brayan Borja Pedraza'),
('yape_qr', 'assets/uploads/payments/yape-qr-brayan.png'),
('order_whatsapp', ''),
('telegram_enabled', '0'),
('telegram_bot_token', ''),
('telegram_chat_id', ''),
('receipt_signing_secret', ''),
('stockflow_schema_marker', 'catalogo_11604');

-- Activa el QR proporcionado también al actualizar una instalación existente.
INSERT INTO store_settings (setting_key, setting_value) VALUES
('yape_enabled', '1'),
('yape_owner', 'Brayan Borja Pedraza'),
('yape_qr', 'assets/uploads/payments/yape-qr-brayan.png')
ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value);

CREATE TABLE IF NOT EXISTS yape_orders (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    order_code VARCHAR(24) NOT NULL UNIQUE,
    customer_name VARCHAR(100) NOT NULL,
    customer_phone VARCHAR(20) NOT NULL DEFAULT '',
    metodo_pago ENUM('yape', 'efectivo') NOT NULL DEFAULT 'efectivo',
    tipo_despacho ENUM('entrega_rapida', 'preparacion') NOT NULL DEFAULT 'preparacion',
    operation_code VARCHAR(40) NOT NULL UNIQUE,
    expected_amount DECIMAL(10,2) UNSIGNED NOT NULL,
    declared_amount DECIMAL(10,2) UNSIGNED NOT NULL,
    monto_paga_con DECIMAL(10,2) NULL,
    vuelto DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    receipt_url VARCHAR(500) NOT NULL,
    status ENUM('pendiente', 'aprobado', 'rechazado') NOT NULL DEFAULT 'pendiente',
    tracking_pin_hash VARCHAR(255) NULL,
    fulfillment_status ENUM('recibido', 'en_preparacion', 'listo', 'entregado', 'cancelado') NOT NULL DEFAULT 'recibido',
    status_updated_at DATETIME NULL,
    delivered_at DATETIME NULL,
    admin_notes VARCHAR(500) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    reviewed_at DATETIME NULL,
    INDEX idx_yape_orders_status_created (status, created_at)
) ENGINE=InnoDB;

ALTER TABLE yape_orders
    ADD COLUMN IF NOT EXISTS customer_phone VARCHAR(20) NOT NULL DEFAULT '' AFTER customer_name,
    ADD COLUMN IF NOT EXISTS metodo_pago ENUM('yape', 'efectivo') NOT NULL DEFAULT 'efectivo' AFTER customer_phone,
    ADD COLUMN IF NOT EXISTS tipo_despacho ENUM('entrega_rapida', 'preparacion') NOT NULL DEFAULT 'preparacion' AFTER metodo_pago,
    ADD COLUMN IF NOT EXISTS monto_paga_con DECIMAL(10,2) NULL AFTER declared_amount,
    ADD COLUMN IF NOT EXISTS vuelto DECIMAL(10,2) NOT NULL DEFAULT 0.00 AFTER monto_paga_con,
    ADD COLUMN IF NOT EXISTS tracking_pin_hash VARCHAR(255) NULL AFTER status,
    ADD COLUMN IF NOT EXISTS fulfillment_status ENUM('recibido', 'en_preparacion', 'listo', 'entregado', 'cancelado') NOT NULL DEFAULT 'recibido' AFTER tracking_pin_hash,
    ADD COLUMN IF NOT EXISTS status_updated_at DATETIME NULL AFTER fulfillment_status,
    ADD COLUMN IF NOT EXISTS delivered_at DATETIME NULL AFTER status_updated_at;

-- Conserva correctamente como Yape los pedidos creados antes de esta migración.
UPDATE yape_orders
SET metodo_pago = 'yape'
WHERE receipt_url <> '' AND operation_code LIKE 'CAP-%';

CREATE TABLE IF NOT EXISTS yape_order_items (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    order_id BIGINT UNSIGNED NOT NULL,
    item_type ENUM('product', 'combo') NOT NULL,
    item_id INT UNSIGNED NOT NULL,
    item_name VARCHAR(160) NOT NULL,
    quantity SMALLINT UNSIGNED NOT NULL,
    presentation ENUM('unidad', 'paquete') NOT NULL DEFAULT 'unidad',
    units_per_item SMALLINT UNSIGNED NOT NULL DEFAULT 1,
    unit_price DECIMAL(10,2) UNSIGNED NOT NULL,
    unit_cost DECIMAL(10,2) UNSIGNED NOT NULL DEFAULT 0.00,
    subtotal DECIMAL(10,2) UNSIGNED NOT NULL,
    profit DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    stock_before INT UNSIGNED NULL,
    stock_after INT UNSIGNED NULL,
    CONSTRAINT fk_yape_order_items_order FOREIGN KEY (order_id) REFERENCES yape_orders(id) ON UPDATE CASCADE ON DELETE CASCADE,
    INDEX idx_yape_order_items_order (order_id)
) ENGINE=InnoDB;

ALTER TABLE yape_order_items
    ADD COLUMN IF NOT EXISTS presentation ENUM('unidad', 'paquete') NOT NULL DEFAULT 'unidad' AFTER quantity,
    ADD COLUMN IF NOT EXISTS units_per_item SMALLINT UNSIGNED NOT NULL DEFAULT 1 AFTER presentation,
    ADD COLUMN IF NOT EXISTS unit_cost DECIMAL(10,2) UNSIGNED NOT NULL DEFAULT 0.00 AFTER unit_price,
    ADD COLUMN IF NOT EXISTS profit DECIMAL(10,2) NOT NULL DEFAULT 0.00 AFTER subtotal,
    ADD COLUMN IF NOT EXISTS stock_before INT UNSIGNED NULL AFTER profit,
    ADD COLUMN IF NOT EXISTS stock_after INT UNSIGNED NULL AFTER stock_before;

-- Completa costos y ganancias de pedidos anteriores cuando todavía estaban vacíos.
UPDATE yape_order_items i
INNER JOIN products p ON i.item_type = 'product' AND p.id = i.item_id
SET i.unit_cost = p.cost_price,
    i.profit = ROUND((i.unit_price - p.cost_price) * i.quantity, 2),
    i.stock_before = COALESCE(i.stock_before, p.stock)
WHERE i.unit_cost = 0.00 AND i.stock_after IS NULL;

CREATE TABLE IF NOT EXISTS inventory_movements (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    product_id INT UNSIGNED NOT NULL,
    movement_type ENUM('entrada', 'salida', 'ajuste_entrada', 'ajuste_salida') NOT NULL,
    presentation ENUM('unidad', 'paquete') NOT NULL DEFAULT 'unidad',
    quantity INT UNSIGNED NOT NULL,
    units_changed INT UNSIGNED NOT NULL,
    unit_cost DECIMAL(10,2) UNSIGNED NOT NULL DEFAULT 0.00,
    sale_price DECIMAL(10,2) UNSIGNED NOT NULL DEFAULT 0.00,
    total_cost DECIMAL(12,2) UNSIGNED NOT NULL DEFAULT 0.00,
    total_income DECIMAL(12,2) UNSIGNED NOT NULL DEFAULT 0.00,
    profit DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    payment_method ENUM('efectivo', 'yape', 'plin', 'tarjeta', 'transferencia', 'otro') NOT NULL DEFAULT 'efectivo',
    reference VARCHAR(100) NULL,
    notes VARCHAR(500) NULL,
    moved_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by INT UNSIGNED NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_movements_product FOREIGN KEY (product_id) REFERENCES products(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_movements_user FOREIGN KEY (created_by) REFERENCES users(id) ON UPDATE CASCADE ON DELETE SET NULL,
    INDEX idx_movements_type (movement_type),
    INDEX idx_movements_date (moved_at),
    INDEX idx_movements_product_date (product_id, moved_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS combos (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(120) NOT NULL,
    description VARCHAR(500) NULL,
    price DECIMAL(10,2) UNSIGNED NOT NULL,
    stock INT UNSIGNED NULL DEFAULT NULL COMMENT 'NULL calcula la disponibilidad automáticamente según los productos',
    image_url VARCHAR(500) NULL,
    featured TINYINT(1) NOT NULL DEFAULT 0,
    active TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_combos_active (active),
    INDEX idx_combos_featured (featured)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS combo_items (
    combo_id INT UNSIGNED NOT NULL,
    product_id INT UNSIGNED NOT NULL,
    quantity SMALLINT UNSIGNED NOT NULL DEFAULT 1,
    PRIMARY KEY (combo_id, product_id),
    CONSTRAINT fk_combo_items_combo FOREIGN KEY (combo_id) REFERENCES combos(id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_combo_items_product FOREIGN KEY (product_id) REFERENCES products(id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- Categorias basicas y categorias que ya existan en los productos.
INSERT IGNORE INTO categories (name, icon, active) VALUES
('Snacks', 'S', 1),
('Galletas', 'G', 1),
('Dulces y chicles', 'D', 1),
('Bebidas', 'B', 1),
('Otros', 'O', 1);

INSERT IGNORE INTO categories (name, icon, active)
SELECT DISTINCT category, UPPER(LEFT(category, 1)), 1
FROM products
WHERE category IS NOT NULL AND category <> '';

-- Catalogo publico de Devioz Store.
-- En una instalacion existente actualiza la ficha publica y completa solo costos que sigan en cero.
-- Los costos ya registrados y el stock local siempre se conservan.
SET @seed_products = IF((SELECT COUNT(*) FROM products) = 0, 1, 0);

INSERT INTO products
(code, name, category, description, cost_price, price, stock, min_stock, units_per_pack, pack_price, image_url, featured, active)
VALUES
('PROD-001', 'Piqueo snack', 'Snacks', 'Producto disponible en nuestra tienda.', 1.95, 2.50, 10, 5, 1, NULL, 'https://devioz.com/store/public/uploads/products/product_9f5bb771d5fee4eea674.webp', 0, 1),
('PROD-002', 'Lay''s pequeñas', 'Snacks', 'Producto disponible en nuestra tienda.', 1.75, 2.00, 10, 5, 1, NULL, 'https://devioz.com/store/public/uploads/products/product_159917019d1360cb7751.jpg', 0, 1),
('PROD-003', 'Lay''s grandes', 'Snacks', 'Producto disponible en nuestra tienda.', 3.75, 8.00, 2, 5, 1, NULL, 'https://devioz.com/store/public/uploads/products/product_c333379562c3aa470272.webp', 0, 1),
('PROD-004', 'Tor-Tees azul', 'Snacks', 'Producto disponible en nuestra tienda.', 1.75, 2.50, 10, 5, 1, NULL, 'https://devioz.com/store/public/uploads/products/product_e26b4bb9115633b0ef86.jpg', 0, 1),
('PROD-005', 'Tor-Tees amarillo', 'Snacks', 'Producto disponible en nuestra tienda.', 1.59, 2.50, 11, 5, 1, NULL, 'https://devioz.com/store/public/uploads/products/product_cbf38af7c58ea8fd3593.jpg', 0, 1),
('PROD-006', 'Chips Ahoy', 'Galletas', 'Producto disponible en nuestra tienda.', 0.00, 2.00, 8, 5, 1, NULL, 'https://devioz.com/store/public/uploads/products/product_459291227f9737accd23.webp', 0, 1),
('PROD-007', 'Glacitas', 'Galletas', 'Producto disponible en nuestra tienda.', 0.00, 1.00, 6, 5, 1, NULL, 'https://devioz.com/store/public/uploads/products/product_9ebc419479fec5aaeb00.webp', 0, 1),
('PROD-008', 'Sublimes', 'Dulces y chicles', 'Producto disponible en nuestra tienda.', 1.04, 1.50, 24, 5, 1, NULL, 'https://devioz.com/store/public/uploads/products/product_5730e8c2485637c27ad2.jpg', 0, 1),
('PROD-009', 'Bubbaloo verde', 'Dulces y chicles', 'Producto disponible en nuestra tienda.', 0.00, 0.30, 70, 5, 1, NULL, 'https://devioz.com/store/public/uploads/products/product_cf9ca82f8a6f2c598c8b.jpg', 0, 1),
('PROD-010', 'Bubbaloo morado', 'Dulces y chicles', 'Producto disponible en nuestra tienda.', 0.00, 0.30, 70, 5, 1, NULL, 'https://devioz.com/store/public/uploads/products/product_fb36e4e09e7ade79f2a1.jpg', 0, 1),
('PROD-011', 'Trident rosa', 'Dulces y chicles', 'Producto disponible en nuestra tienda.', 1.11, 2.00, 18, 5, 1, NULL, 'https://devioz.com/store/public/uploads/products/product_035bb78d8030f2e7a3a0.jpg', 0, 1),
('PROD-012', 'Trident morado', 'Dulces y chicles', 'Producto disponible en nuestra tienda.', 1.11, 2.00, 18, 5, 1, NULL, 'https://devioz.com/store/public/uploads/products/product_13349bb153174e00b3dd.jpg', 0, 1),
('PROD-013', 'Guarana', 'Bebidas', 'Producto disponible en nuestra tienda.', 0.00, 2.00, 15, 5, 6, 12.00, 'https://devioz.com/store/public/uploads/products/product_bc47d898f93f2c139860.png', 0, 1),
('PROD-014', 'Inca Kola', 'Bebidas', 'Producto disponible en nuestra tienda.', 0.00, 3.50, 12, 5, 6, 21.00, 'https://devioz.com/store/public/uploads/products/product_9e1e08a2554ee2cc2d52.png', 0, 1),
('PROD-015', 'Coca-Cola', 'Bebidas', 'Producto disponible en nuestra tienda.', 0.00, 3.50, 12, 5, 6, 21.00, 'https://devioz.com/store/public/uploads/products/product_afe887f160487dad1bb9.png', 0, 1),
('PROD-016', 'Volt', 'Bebidas', 'Producto disponible en nuestra tienda.', 0.00, 2.50, 12, 5, 6, 15.00, 'https://devioz.com/store/public/uploads/products/product_957695ec33f89d113c8b.jpg', 1, 1),
('PROD-017', 'Sporade', 'Bebidas', 'Producto disponible en nuestra tienda.', 1.21, 2.50, 12, 5, 6, 15.00, 'https://devioz.com/store/public/uploads/products/product_c7c44c97e719a915471e.jpg', 0, 1),
('PROD-018', 'Agua', 'Bebidas', 'Producto disponible en nuestra tienda.', 0.00, 1.50, 15, 5, 6, 9.00, 'https://devioz.com/store/public/uploads/products/product_1ac2deb447c65c2b7450.webp', 0, 1)
ON DUPLICATE KEY UPDATE
    name = VALUES(name),
    category = VALUES(category),
    description = VALUES(description),
    cost_price = IF(products.cost_price = 0, VALUES(cost_price), products.cost_price),
    price = VALUES(price),
    min_stock = VALUES(min_stock),
    units_per_pack = VALUES(units_per_pack),
    pack_price = VALUES(pack_price),
    image_url = VALUES(image_url),
    featured = VALUES(featured),
    active = VALUES(active);

-- Convierte la imagen principal existente en la primera imagen de la galería.
INSERT INTO product_images (product_id, image_url, sort_order)
SELECT p.id, p.image_url, 0
FROM products p
WHERE p.image_url IS NOT NULL AND p.image_url <> ''
  AND NOT EXISTS (
      SELECT 1 FROM product_images pi
      WHERE pi.product_id = p.id AND pi.image_url = p.image_url
  );

-- Combos iniciales. También se crean al actualizar una instalación que aún no los tenga.
INSERT INTO combos (name, description, price, featured, active)
SELECT 'Combo pelicula', 'Piqueo snack, galletas y una bebida para compartir.', 7.50, 1, 1 FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM combos WHERE name = 'Combo pelicula');

INSERT INTO combos (name, description, price, featured, active)
SELECT 'Combo refrescante', 'Dos bebidas y un snack a precio especial.', 6.50, 1, 1 FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM combos WHERE name = 'Combo refrescante');

UPDATE combos SET description = 'Piqueo snack, galletas y una bebida para compartir.', price = 7.50, featured = 1, active = 1
WHERE name = 'Combo pelicula';

UPDATE combos SET description = 'Dos bebidas y un snack a precio especial.', price = 6.50, featured = 1, active = 1
WHERE name = 'Combo refrescante';

DELETE ci FROM combo_items ci
INNER JOIN combos c ON c.id = ci.combo_id
WHERE c.name IN ('Combo pelicula', 'Combo refrescante');

INSERT IGNORE INTO combo_items (combo_id, product_id, quantity)
SELECT c.id, p.id, x.quantity
FROM (
    SELECT 'Combo pelicula' AS combo_name, 'PROD-001' AS product_code, 1 AS quantity
    UNION ALL SELECT 'Combo pelicula', 'PROD-006', 1
    UNION ALL SELECT 'Combo pelicula', 'PROD-014', 1
    UNION ALL SELECT 'Combo refrescante', 'PROD-002', 1
    UNION ALL SELECT 'Combo refrescante', 'PROD-015', 1
    UNION ALL SELECT 'Combo refrescante', 'PROD-018', 1
) x
INNER JOIN combos c ON c.name = x.combo_name
INNER JOIN products p ON p.code = x.product_code;

SET FOREIGN_KEY_CHECKS = 1;

-- Immutable Yape checkout snapshots (canonical upgrade: upgrade_yape_order_snapshots.sql).
ALTER TABLE yape_orders ADD COLUMN IF NOT EXISTS reserved_until DATETIME NULL AFTER fulfillment_status;
ALTER TABLE yape_orders ADD COLUMN IF NOT EXISTS inventory_snapshot_version TINYINT UNSIGNED NOT NULL DEFAULT 0 AFTER reserved_until;
ALTER TABLE yape_order_items ADD COLUMN IF NOT EXISTS manual_combo_stock_reserved TINYINT(1) NULL AFTER units_per_item;
CREATE TABLE IF NOT EXISTS yape_order_item_components (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, order_item_id BIGINT UNSIGNED NOT NULL,
    product_id INT UNSIGNED NOT NULL, product_name VARCHAR(160) NOT NULL,
    units_per_combo SMALLINT UNSIGNED NOT NULL, reserved_units INT UNSIGNED NOT NULL,
    unit_cost DECIMAL(10,2) UNSIGNED NOT NULL DEFAULT 0.00,
    reference_unit_price DECIMAL(10,2) UNSIGNED NOT NULL DEFAULT 0.00,
    allocated_income DECIMAL(12,2) UNSIGNED NOT NULL DEFAULT 0.00,
    total_cost DECIMAL(12,2) UNSIGNED NOT NULL DEFAULT 0.00,
    profit DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY yape_order_item_component_unique (order_item_id, product_id),
    KEY idx_yape_order_item_components_product (product_id),
    CONSTRAINT fk_yape_order_item_components_item FOREIGN KEY (order_item_id) REFERENCES yape_order_items(id) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Nutricion verificable y pagos ampliados.
CREATE TABLE IF NOT EXISTS product_nutrition (
  product_id INT UNSIGNED NOT NULL PRIMARY KEY,
  applicability ENUM('food','non_food','review') NOT NULL DEFAULT 'review',
  energy_kcal_100g DECIMAL(10,2) NULL,
  serving_size DECIMAL(10,2) NULL,
  serving_unit ENUM('g','ml','unit') NULL,
  energy_kcal_serving DECIMAL(10,2) NULL,
  protein_g DECIMAL(10,2) NULL,
  carbohydrate_g DECIMAL(10,2) NULL,
  fat_g DECIMAL(10,2) NULL,
  source_type ENUM('label','open_food_facts','ins','usda','manual') NULL,
  source_ref VARCHAR(255) NULL,
  confidence ENUM('verified','reference') NULL,
  verified_at DATETIME NULL,
  verified_by INT UNSIGNED NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_product_nutrition_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO store_settings(setting_key,setting_value) VALUES
('plin_enabled','0'),('plin_phone',''),('plin_owner',''),('plin_qr','');

ALTER TABLE yape_orders MODIFY metodo_pago ENUM('yape','plin','efectivo','tarjeta') NOT NULL DEFAULT 'efectivo';

CREATE TABLE IF NOT EXISTS culqi_payment_events (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  provider_event_id VARCHAR(120) NOT NULL,
  provider_charge_id VARCHAR(120) NULL,
  order_id BIGINT UNSIGNED NULL,
  status VARCHAR(40) NOT NULL DEFAULT 'received',
  payload_hash CHAR(64) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_culqi_event (provider_event_id),
  UNIQUE KEY uq_culqi_charge (provider_charge_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- FIN del esquema de la aplicación. Para una instalación completa usa
-- database/devioz_shop_integrada.sql.
