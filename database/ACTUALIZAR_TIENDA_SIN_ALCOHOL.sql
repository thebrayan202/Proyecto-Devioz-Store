-- Ejecutar DESPUES de la instalacion, sobre la base elegida en phpMyAdmin.
-- Conserva las existencias; no cambia una bebida real por un nombre falso.

-- Todo articulo de edad restringida queda inactivo y sin venta.
UPDATE products
SET restricted = 1, active = 0, sale_enabled = 0
WHERE LOWER(CONCAT_WS(' ', name, category, description)) REGEXP
  '(^|[^[:alnum:]])(cervezas?|vinos?|licor(es)?|alcohol(ica|ico|icas|icos)?|whisk(y|ey)|vodka|ron|pisco|tequila|ginebra|gin|brandy|champagne|sidra|espumante|tabaco|cigarro|nicotina|vapeador|cannabis|marihuana)([^[:alnum:]]|$)|bebida[[:space:]]+energizante|energy[[:space:]]+drink';

-- Publicar solo productos propios existentes con stock real, precio y texto permitido.
UPDATE products
SET active = 1, sale_enabled = 1
WHERE catalog_scope = 'master' AND restricted = 0 AND stock > 0 AND price > 0
  AND LOWER(CONCAT_WS(' ', name, category, description)) NOT REGEXP
  '(^|[^[:alnum:]])(cervezas?|vinos?|licor(es)?|alcohol(ica|ico|icas|icos)?|whisk(y|ey)|vodka|ron|pisco|tequila|ginebra|gin|brandy|champagne|sidra|espumante|tabaco|cigarro|nicotina|vapeador|cannabis|marihuana)([^[:alnum:]]|$)|bebida[[:space:]]+energizante|energy[[:space:]]+drink';

-- Los productos iniciales de la tienda eran 'legacy': se vuelven comprables si hay stock.
UPDATE products
SET catalog_scope = 'master', active = 1, sale_enabled = IF(stock > 0 AND price > 0, 1, 0)
WHERE code IN ('PROD-001','PROD-002','PROD-003','PROD-004','PROD-005','PROD-006',
               'PROD-007','PROD-008','PROD-009','PROD-010','PROD-011','PROD-012',
               'PROD-013','PROD-014','PROD-015','PROD-017','PROD-018')
  AND restricted = 0
  AND LOWER(CONCAT_WS(' ', name, category, description)) NOT REGEXP
  '(^|[^[:alnum:]])(cervezas?|vinos?|licor(es)?|alcohol(ica|ico|icas|icos)?|whisk(y|ey)|vodka|ron|pisco|tequila|ginebra|gin|brandy|champagne|sidra|espumante)([^[:alnum:]]|$)';

-- Bebidas nuevas genuinamente sin alcohol: stock cero hasta registrar unidades reales.
INSERT INTO products (code, name, category, description, cost_price, price, stock,
                      active, catalog_scope, sale_enabled, restricted, source_name)
VALUES
('SIN-ALC-001', 'Agua mineral sin gas', 'Bebidas', 'Botella de agua mineral.', 0, 2.00, 0, 1, 'master', 0, 0, 'Devioz'),
('SIN-ALC-002', 'Gaseosa de limón', 'Bebidas', 'Bebida gaseosa sabor limón.', 0, 3.00, 0, 1, 'master', 0, 0, 'Devioz'),
('SIN-ALC-003', 'Jugo de maracuyá', 'Bebidas', 'Jugo sabor maracuyá.', 0, 3.50, 0, 1, 'master', 0, 0, 'Devioz')
ON DUPLICATE KEY UPDATE code = code;

-- Combos antiguos con componentes restringidos permanecen desactivados.
UPDATE combos c
SET active = 0
WHERE EXISTS (
    SELECT 1 FROM combo_items ci INNER JOIN products p ON p.id = ci.product_id
    WHERE ci.combo_id = c.id AND p.restricted = 1
);
