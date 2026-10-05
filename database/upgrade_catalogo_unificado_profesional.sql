-- Devioz Store: catálogo unificado, rentabilidad, contenido e IA.
-- Migración no destructiva para MariaDB/MySQL de XAMPP.

CREATE TABLE IF NOT EXISTS external_product_pricing (
  external_product_id INT(11) NOT NULL PRIMARY KEY,
  custom_sale_price DECIMAL(10,2) NULL,
  custom_margin_pct DECIMAL(7,2) NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_external_pricing_product FOREIGN KEY (external_product_id)
    REFERENCES productos(id_producto) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO store_settings(setting_key,setting_value)
VALUES ('external_default_margin_pct','25.00')
ON DUPLICATE KEY UPDATE setting_value=setting_value;

SET @idx_busqueda = (SELECT COUNT(*) FROM information_schema.statistics WHERE table_schema=DATABASE() AND table_name='productos' AND index_name='idx_productos_busqueda');
SET @sql_busqueda = IF(@idx_busqueda=0,'CREATE INDEX idx_productos_busqueda ON productos(producto, categoria, supermercado, activo)','SELECT 1');
PREPARE stmt_busqueda FROM @sql_busqueda; EXECUTE stmt_busqueda; DEALLOCATE PREPARE stmt_busqueda;
SET @idx_precio = (SELECT COUNT(*) FROM information_schema.statistics WHERE table_schema=DATABASE() AND table_name='productos' AND index_name='idx_productos_precio');
SET @sql_precio = IF(@idx_precio=0,'CREATE INDEX idx_productos_precio ON productos(precio_actual)','SELECT 1');
PREPARE stmt_precio FROM @sql_precio; EXECUTE stmt_precio; DEALLOCATE PREPARE stmt_precio;

CREATE OR REPLACE VIEW v_unified_products AS
SELECT CONCAT('internal:',p.id) AS item_key, 'internal' AS source_type, p.id AS source_id,
       'Devioz' AS source_name, p.name, '' AS brand, p.code, p.category,
       IF(p.units_per_pack>1,CONCAT(p.units_per_pack,' unidades'),'Unidad') AS presentation,
       p.cost_price AS cost, p.price AS sale_price, p.stock, p.active AS available,
       p.image_url, p.updated_at, 'real' AS profit_type
FROM products p
UNION ALL
SELECT CONCAT('external:',e.id_producto), 'external' AS source_type, e.id_producto,
       COALESCE(s.nombre,NULLIF(e.supermercado,''),'Proveedor'), e.producto, COALESCE(e.marca,''),
       COALESCE(NULLIF(e.ean,''),CONCAT('EXT-',e.id_producto)), COALESCE(e.categoria,'Sin categoría'),
       COALESCE(NULLIF(e.presentacion,''),NULLIF(e.unidad,''),'Unidad'), e.precio_actual,
       CASE WHEN e.precio_actual IS NULL OR e.precio_actual<=0 THEN NULL ELSE
         COALESCE(ep.custom_sale_price,ROUND(e.precio_actual*(1+COALESCE(ep.custom_margin_pct,CAST(cfg.setting_value AS DECIMAL(7,2)),25)/100),2)) END,
       NULL, CASE WHEN e.activo=1 AND UPPER(COALESCE(e.estado_disponibilidad,'DISPONIBLE')) NOT IN ('NO DISPONIBLE','AGOTADO','SIN STOCK') THEN 1 ELSE 0 END,
       e.imagen, COALESCE(e.fecha_extraccion,e.fecha_carga), 'estimated'
FROM productos e
LEFT JOIN supermercados s ON s.id_supermercado=e.id_supermercado
LEFT JOIN external_product_pricing ep ON ep.external_product_id=e.id_producto
LEFT JOIN store_settings cfg ON cfg.setting_key='external_default_margin_pct';

CREATE TABLE IF NOT EXISTS store_banners (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(120) NOT NULL,
  subtitle VARCHAR(240) NULL,
  image_url VARCHAR(500) NULL,
  link_url VARCHAR(500) NULL,
  starts_at DATETIME NULL,
  ends_at DATETIME NULL,
  position SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  active TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_store_banners_active_dates(active,starts_at,ends_at,position)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS store_featured_products (
  product_id INT UNSIGNED NOT NULL PRIMARY KEY,
  position SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  active TINYINT(1) NOT NULL DEFAULT 1,
  CONSTRAINT fk_featured_internal_product FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE CASCADE,
  INDEX idx_store_featured_position(active,position)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS storefront_section_settings (
  section_key VARCHAR(40) PRIMARY KEY,
  title VARCHAR(120) NOT NULL,
  subtitle VARCHAR(240) NULL,
  active TINYINT(1) NOT NULL DEFAULT 1,
  position SMALLINT UNSIGNED NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO storefront_section_settings(section_key,title,subtitle,active,position) VALUES
('offers','Ofertas para aprovechar','Precios especiales disponibles hoy',1,10),
('recommended','Recomendados para ti','Productos disponibles en Devioz',1,20),
('bestsellers','Los más elegidos','Favoritos de nuestros clientes',1,30),
('combos','Combos Devioz','Más productos en una sola compra',1,40);

CREATE TABLE IF NOT EXISTS ai_usage_daily (
  usage_day DATE NOT NULL PRIMARY KEY,
  searches INT UNSIGNED NOT NULL DEFAULT 0,
  ollama_answers INT UNSIGNED NOT NULL DEFAULT 0,
  rule_fallbacks INT UNSIGNED NOT NULL DEFAULT 0,
  confirmed_additions INT UNSIGNED NOT NULL DEFAULT 0,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
