-- DEVIOZ STORE: clientes, favoritos, delivery, cupones, reservas, roles y auditoría.
-- Compatible con MariaDB 10.4+ / XAMPP. No elimina información existente.
USE devioz_shop;

-- El catálogo externo shopping_sources/shopping_offers queda fuera de este
-- suite porque en XAMPP puede quedar un tablespace .ibd huérfano y bloquear
-- toda la actualización (#1813). Si necesitas ese módulo, importa aparte
-- database/upgrade_shopping_sources.sql después de reparar el tablespace.

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
