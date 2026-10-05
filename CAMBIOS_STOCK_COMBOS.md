# Stock de combos

## Actualizar una instalación existente

1. Abre `phpMyAdmin` y selecciona la base de datos `stockflow`.
2. Entra en **Importar**.
3. Importa `database/upgrade_combo_stock.sql` una sola vez.
4. Reemplaza los archivos del proyecto por los de este paquete.

## Cómo funciona

- En **Combos**, el campo **Stock del combo** permite escribir una cantidad o usar los botones `−` y `+`.
- **Calcular según productos** coloca la cantidad máxima que puede armarse con el stock actual.
- Si el campo queda vacío, el stock funciona en modo automático según los productos incluidos.
- La cantidad disponible para vender siempre será el menor valor entre el stock configurado y la capacidad de los productos.
- Al vender un combo se descuentan sus productos y, cuando existe un stock manual, también se descuenta una unidad del stock del combo.
