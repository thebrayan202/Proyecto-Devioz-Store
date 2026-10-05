# Actualización de la tienda (snacks y bebidas sin alcohol)

Esta copia no cambia el nombre de una bebida alcohólica para hacerla pasar por otra. Desactiva los productos restringidos y agrega fichas nuevas de agua, gaseosa y jugo. Las fichas nuevas comienzan con **stock 0**: registra el inventario real antes de venderlas.

## Si la tienda ya está instalada

1. Haz un respaldo de la base desde phpMyAdmin.
2. Sustituye la carpeta `stockflow` del servidor por la de este ZIP, conservando cualquier configuración local y tus imágenes. Usa el nombre de base indicado en `config/database.php`.
3. En phpMyAdmin, selecciona **esa misma base** e importa **solo** `database/ACTUALIZAR_TIENDA_SIN_ALCOHOL.sql`. No vuelvas a importar el SQL de instalación completa sobre una base con pedidos.
4. En el panel, comprueba que los productos propios con stock y precio estén publicados. Si una ficha nueva aún tiene stock 0, registra la entrada real en Inventario.
5. En **Combos**, el buscador muestra productos aptos con stock. Selecciona las unidades por combo y deja el stock del combo vacío para calcularlo automáticamente. Un combo activo publicará sus componentes aptos si todavía estaban sin publicar.
6. Haz una compra de prueba de un snack o una bebida sin alcohol: elige entrega o recojo, completa nombre y celular, y confirma. También puedes probar registro e ingreso en **Mi cuenta**.

La entrega es opcional: si dejas «Sin entrega · recojo en tienda», el pedido se calcula sin cargo de envío y no requiere dirección. Para envío a domicilio, selecciona una zona y completa la dirección. La opción «Recojo en tienda» debe estar activa en `delivery_zones` (la instalación completa la incluye).

En **Administrador → Categorías**, abre «Ver productos y categorías» debajo de una categoría para consultar sus productos, buscarlos por nombre o código y asignar individualmente otra categoría activa con «Guardar». Se muestran 20 por página; los productos del inventario vinculados a importaciones aparecen una sola vez. Estos cambios se guardan en la base de datos existente, así que no necesitas una migración SQL adicional para esta pantalla.

Las imágenes en **Catálogo** se ajustan al espacio de la foto y no cubren el nombre ni el precio. En **Administrador → Combos**, aparecen primero los productos activos con stock y precio; puedes buscar otro por nombre, código o EAN y pulsar «Agregar». Los productos seleccionados quedan debajo del buscador con su cantidad. Si no aparece uno, verifica que sea una ficha del catálogo maestro, activa, con stock y precio reales.

En la portada hay un acceso directo a **productos disponibles para comprar**. En el catálogo puedes activar «Listos para comprar» y abrir «Más filtros» solo si necesitas elegir precios, despacho o cantidad de resultados. Las fotos de productos y combos se ajustan sin recortarse y muestran un icono si falla la carga. En el pedido, al elegir recojo en tienda se ocultan dirección y referencia; aparecen al seleccionar una zona de entrega. Estos cambios de interfaz no requieren importar SQL adicional.

### Si todas las tarjetas dicen «Precio referencial»

Ese texto indica que los productos importados aún no están preparados para venderse. Ve a **Administrador → Todos los productos**, busca uno que tengas físicamente y pulsa **Preparar venta**. Registra **costo, precio de venta y stock real mayor que cero**; deja marcadas las opciones **Producto activo** y **Habilitado para venta**, y guarda. Actualiza la portada: ese producto aparecerá primero con el botón **Comprar**. Los miles de productos externos con stock 0 seguirán como referencia hasta que registres sus existencias reales.

## Instalación nueva

Importa el SQL de instalación del README original y, después, importa `database/ACTUALIZAR_TIENDA_SIN_ALCOHOL.sql` en la misma base. Las instrucciones de cuentas administrativas están en el README principal.

No pongas stock ficticio a las bebidas nuevas. Si tienes una copia de la base anterior con datos reales, verifica con cuidado que la copia y el nombre de la base coincidan antes de importar.
