-- Ejecuta este archivo una sola vez en phpMyAdmin si ya tienes StockFlow instalado.
-- NULL mantiene el modo automático basado en el stock de los productos incluidos.

ALTER TABLE combos
    ADD COLUMN IF NOT EXISTS stock INT UNSIGNED NULL DEFAULT NULL
    COMMENT 'NULL calcula la disponibilidad automáticamente según los productos'
    AFTER price;
