-- STOCKFLOW - MIGRACIÓN: EFECTIVO Y CLASIFICACIÓN DE DESPACHO
-- El proyecto existente usa `products` y `yape_orders` como tablas de productos y pedidos.

USE stockflow;

ALTER TABLE products
    ADD COLUMN IF NOT EXISTS entrega_inmediata TINYINT(1) NOT NULL DEFAULT 1 AFTER featured;

ALTER TABLE yape_orders
    ADD COLUMN IF NOT EXISTS customer_phone VARCHAR(20) NOT NULL DEFAULT '' AFTER customer_name,
    ADD COLUMN IF NOT EXISTS metodo_pago ENUM('yape', 'efectivo') NOT NULL DEFAULT 'efectivo' AFTER customer_phone,
    ADD COLUMN IF NOT EXISTS tipo_despacho ENUM('entrega_rapida', 'preparacion') NOT NULL DEFAULT 'preparacion' AFTER metodo_pago,
    ADD COLUMN IF NOT EXISTS monto_paga_con DECIMAL(10,2) NULL AFTER declared_amount,
    ADD COLUMN IF NOT EXISTS vuelto DECIMAL(10,2) NOT NULL DEFAULT 0.00 AFTER monto_paga_con;

UPDATE yape_orders
SET metodo_pago = 'yape'
WHERE receipt_url <> '' AND operation_code LIKE 'CAP-%';
