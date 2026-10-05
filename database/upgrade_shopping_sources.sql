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
