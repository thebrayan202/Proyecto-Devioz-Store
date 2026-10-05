-- STOCKFLOW - CONFIGURACION DE NOTIFICACIONES POR TELEGRAM
-- Importación opcional para instalaciones existentes. No modifica pedidos ni productos.

USE stockflow;

CREATE TABLE IF NOT EXISTS store_settings (
    setting_key VARCHAR(80) PRIMARY KEY,
    setting_value TEXT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

INSERT IGNORE INTO store_settings (setting_key, setting_value) VALUES
('telegram_enabled', '0'),
('telegram_bot_token', ''),
('telegram_chat_id', ''),
('receipt_signing_secret', '');
