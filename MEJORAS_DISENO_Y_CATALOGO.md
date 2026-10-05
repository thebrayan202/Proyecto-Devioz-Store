# Mejoras de diseño y catálogo

Esta versión simplifica la tienda y el panel administrativo sin eliminar datos ni módulos.

## Catálogo público

- Solo muestra productos permitidos, con precio mayor que cero, stock disponible y sin ocultación manual.
- Un producto desaparece automáticamente cuando su stock llega a cero.
- Las imágenes que no cargan se reemplazan por un marcador visual limpio.
- Se eliminaron opciones y mensajes de productos de referencia que no podían comprarse.

## Administración

- El menú principal se concentra en Productos, Categorías, Combos, Inventario, Pagos, Pedidos, Clientes y Contenido.
- Proveedores, catálogo externo, IA, comparador, estadísticas, reservas y respaldos siguen disponibles dentro de **Herramientas avanzadas**.
- La pantalla **Productos** permite aplicar cambios a los productos seleccionados o a toda la base de datos.
- **Mostrar cuando tenga stock** prepara los productos para aparecer automáticamente al registrar existencias y precio.
- **Ocultar manualmente** retira productos del catálogo aunque todavía tengan stock.
- Los productos creados manualmente aparecen automáticamente cuando tienen precio y stock, salvo que se marque **Ocultar aunque tenga stock**.

## Uso recomendado tras actualizar

1. Abre **Administración → Productos**.
2. En **Aplicar a**, elige **Toda la base de datos**.
3. Selecciona **Mostrar cuando tenga stock** y revisa la confirmación.
4. Ajusta precio y stock únicamente de los productos que deseas vender.
5. Usa **Ocultar aunque tenga stock** para pausar cualquier producto de forma temporal.

Los productos restringidos nunca se publican mediante las acciones masivas.
# Entrega nutricion, checkout y admin simple

Se agregaron las especificaciones pedidas al proyecto:

- Productos visibles solo con stock, precio y visibilidad permitida.
- Calorías por producto con fuente verificable y exclusión de productos que no son comida.
- Checkout dinámico por pasos con efectivo, Yape, Plin y tarjeta preparada para Culqi.
- Panel admin más simple con pendientes, edición rápida y estados claros.
- Cálculo de combos desde stock real para evitar publicar combos imposibles.

Para tarjeta real falta colocar las llaves del comercio Culqi en el servidor. Sin esas llaves, la opción no aparece como método disponible.
