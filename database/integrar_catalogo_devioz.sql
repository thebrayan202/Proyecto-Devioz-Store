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
