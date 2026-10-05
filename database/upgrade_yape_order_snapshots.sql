-- Freeze Yape order facts and make reservation release idempotent (MariaDB 10.4+).
ALTER TABLE yape_orders
    ADD COLUMN IF NOT EXISTS reserved_until DATETIME NULL AFTER fulfillment_status;
ALTER TABLE yape_orders
    ADD COLUMN IF NOT EXISTS inventory_snapshot_version TINYINT UNSIGNED NOT NULL DEFAULT 0 AFTER reserved_until;

ALTER TABLE yape_order_items
    ADD COLUMN IF NOT EXISTS manual_combo_stock_reserved TINYINT(1) NULL AFTER units_per_item;

CREATE TABLE IF NOT EXISTS yape_order_item_components (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    order_item_id BIGINT UNSIGNED NOT NULL,
    product_id INT UNSIGNED NOT NULL,
    product_name VARCHAR(160) NOT NULL,
    units_per_combo SMALLINT UNSIGNED NOT NULL,
    reserved_units INT UNSIGNED NOT NULL,
    unit_cost DECIMAL(10,2) UNSIGNED NOT NULL DEFAULT 0.00,
    reference_unit_price DECIMAL(10,2) UNSIGNED NOT NULL DEFAULT 0.00,
    allocated_income DECIMAL(12,2) UNSIGNED NOT NULL DEFAULT 0.00,
    total_cost DECIMAL(12,2) UNSIGNED NOT NULL DEFAULT 0.00,
    profit DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY yape_order_item_component_unique (order_item_id, product_id),
    KEY idx_yape_order_item_components_product (product_id),
    CONSTRAINT fk_yape_order_item_components_item
        FOREIGN KEY (order_item_id) REFERENCES yape_order_items(id)
        ON UPDATE CASCADE ON DELETE CASCADE
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
