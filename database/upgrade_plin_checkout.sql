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
