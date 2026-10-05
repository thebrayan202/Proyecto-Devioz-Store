# Recibos tipo ticket y mejoras para celular

## Recibo
Diseño blanco y negro con Devioz Store, mensaje comercial y web devioz.com.
Panel Administración → Datos de empresa para editar encabezado, razón social,
RUC, dirección y teléfono. No se inventaron identificadores ni datos de contacto:
los campos faltantes permanecen vacíos y no se imprimen. Los datos de empresa
actuales se aplican también al volver a abrir recibos antiguos.

El ticket conserva número único, pedido, fecha/hora de entrega, detalle y cantidades,
precios unitarios, subtotales, total, forma de pago, efectivo recibido y vuelto.
Presentaciones vendidas cuenta unidades de venta: un pack cuenta como una
presentación; un combo también. Datos ausentes de efectivo muestran No registrado.
Código de barras Code128 B con el número interno del recibo (no contiene token
ni datos personales). No es un código fiscal ni un enlace de consulta automático.
El documento indica que es interno y no es boleta ni factura electrónica.
No se añadieron donaciones, impuestos o descuentos que no estén registrados.

## Guardar, imprimir y compartir
- Imprimir / guardar PDF: abre el diálogo nativo del navegador.
- Formatos: ticket 58 mm, 80 mm o hoja A4/PDF. Selecciona también el papel correcto
  en la impresora y desactiva encabezados/pies del navegador.
- Descargar texto: descarga un TXT de la compra desde el servidor.
- Compartir: usa el menú nativo si está disponible en HTTPS; en caso contrario
  ofrece copiar el enlace o seleccionarlo manualmente.
- Copiar enlace: requiere permiso y soporte; incluye selección manual alternativa.
Los enlaces permiten consultar el recibo a quien los reciba. No se envía nada
sin que la persona pulse y confirme en la aplicación elegida. La integración
Telegram existente sigue usando el mismo enlace protegido.

El PDF depende del navegador: no se añadió un generador PDF en el servidor.
En iPhone puede ser necesario usar las opciones Compartir / Imprimir / Archivos
del navegador. La impresión física y la lectura de barras requieren prueba con
la impresora/lector concretos (80 mm ofrece más espacio para el código).

## Celular
Menú horizontal visible con enlaces al catálogo, combos y asistente; controles
táctiles de al menos 44 px en los grupos ajustados. Inputs a 16 px, formularios en
una columna, opciones de recibo apiladas, nombres largos con salto de línea y
ventana de pago desplazable con altura dinámica. Mi lista lleva al catálogo si
se pulsa desde una pantalla que no contiene el carrito.
El seguimiento deja de recargarse al entregar o cancelar; mientras está pendiente
solo recarga cuando la pestaña está visible.

## Instalación desde la versión anterior
Sube los archivos modificados:
- recibo.php
- mi_pedido.php
- includes/admin_header.php
- assets/css/styles.css
- assets/js/app.js

Y los archivos nuevos:
- includes/receipt_layout.php
- includes/receipt_ticket.php
- admin/datos_empresa.php
- assets/css/receipt.css
- assets/js/receipt.js
- tests/receipt_interactions.cjs (prueba opcional en Node)

No requiere migración nueva. Usa store_settings, que ya utiliza el proyecto.
Conserva config/database.php, tu configuración de IA y tus archivos subidos.
Después de subir, actualiza la página para cargar estilos nuevos; si un navegador
conserva receipt.css/receipt.js anteriores, fuerza la recarga.

## Validación realizada y pendiente
Revisión sintáctica de PHP con parser y de ambos JavaScript con Node; pruebas
con DOM simulado de copiar, fallback manual, compartir cancelado/error, selector
de papel e impresión (7 comprobaciones). El codificador Code128 B se contrastó
con una implementación de referencia para una cadena de prueba.
El navegador de revisión bloqueó la URL local. No se pudo verificar visualmente
la vista móvil ni ejecutar PHP/MySQL aquí. Falta comprobar en tu instalación:
acceso autorizado/denegado, pedido entregado en efectivo y Yape, descarga TXT,
impresión/PDF y recorrido de catálogo/pago en un Android o iPhone real.
