-- Ejecuta este archivo una sola vez si ya tienes StockFlow instalado.
-- No elimina productos, ventas ni comprobantes existentes.

USE stockflow;

ALTER TABLE yape_orders
    ADD COLUMN IF NOT EXISTS tracking_pin_hash VARCHAR(255) NULL AFTER status,
    ADD COLUMN IF NOT EXISTS fulfillment_status ENUM('recibido', 'en_preparacion', 'listo', 'entregado', 'cancelado') NOT NULL DEFAULT 'recibido' AFTER tracking_pin_hash,
    ADD COLUMN IF NOT EXISTS status_updated_at DATETIME NULL AFTER fulfillment_status,
    ADD COLUMN IF NOT EXISTS delivered_at DATETIME NULL AFTER status_updated_at;

UPDATE yape_orders
SET fulfillment_status = CASE
    WHEN status = 'rechazado' THEN 'cancelado'
    WHEN status = 'aprobado' THEN 'recibido'
    ELSE 'recibido'
END
WHERE fulfillment_status IS NULL OR fulfillment_status = '';

