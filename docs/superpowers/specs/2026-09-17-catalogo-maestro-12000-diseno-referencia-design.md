# Devioz Store: catálogo maestro de 12 mil productos y rediseño profesional

**Fecha:** 2026-09-17  
**Estado:** diseño aprobado, pendiente de plan de implementación

## 1. Objetivo

Transformar el proyecto PHP/MySQL existente en una tienda y administración profesional cuya base operativa sea el catálogo de 11,604 registros de `productos` presente en el archivo adjunto —los 12 mil productos aproximados indicados por el usuario—. El inventario pequeño anterior dejará de alimentar la operación diaria, pero se conservará completo en tablas históricas ocultas.

La tienda pública seguirá el lenguaje visual de las capturas entregadas: navegación de supermercado, buscador protagonista, promociones, categorías y tarjetas de producto. La administración tendrá navegación lateral, indicadores, gráficos, alertas y una tabla rápida para operar miles de productos. Se tomará la estructura como referencia, sin copiar marcas ni recursos gráficos de terceros.

## 2. Decisiones aprobadas

- Los registros de `productos` serán el nuevo catálogo maestro.
- Los productos anteriores, movimientos y relaciones se respaldarán y quedarán fuera de las vistas normales.
- Los 11,604 registros actuales estarán disponibles en administración desde la migración; el diseño admite futuras ampliaciones del catálogo.
- Ningún producto se venderá automáticamente después de migrar.
- La tienda pública mostrará únicamente productos activados para venta, con stock y precio válidos.
- La activación podrá hacerse por producto, selección, categoría o proveedor.
- El margen global inicial será 25 %, editable; cada producto podrá tener precio o margen personalizado.
- Los precios de proveedor se conservarán separados del precio final de Devioz.
- Los artículos restringidos por edad quedarán excluidos de la tienda pública y de la IA.
- La interfaz usará azul noche, blanco, turquesa y verde, adaptada a computadora y celular.
- Ollama con un modelo 4B será el motor principal de recomendaciones y existirá un respaldo por reglas cuando no esté disponible.

## 3. Arquitectura de datos objetivo

### 3.1 Capas

1. **Catálogo de origen:** `productos` conserva cada ficha importada, su proveedor, precio observado, EAN, imagen y fecha de extracción.
2. **Inventario operativo:** `products` se reconstruye con una fila operable por ficha del catálogo maestro y agrega stock, costo, precio Devioz, margen y estado de publicación.
3. **Histórico anterior:** las tablas operativas actuales y sus relaciones se copian con prefijo `legacy_` y quedan accesibles únicamente en una sección de respaldo.
4. **Operación nueva:** movimientos, imágenes, destacados, combos y reservas vuelven a apuntar al nuevo `products`.
5. **Pedidos históricos:** `yape_orders` y `yape_order_items` se conservan porque los ítems ya guardan nombre, precio, costo, utilidad y existencias como instantáneas de la venta. No se reinterpretarán con los identificadores nuevos.

### 3.2 Campos operativos del nuevo `products`

Además de los campos compatibles existentes, el inventario incluirá:

| Campo | Propósito |
|---|---|
| `source_product_id` | Identificador de la ficha en `productos` |
| `source_name` | Tottus, Plaza Vea, Metro u otro proveedor |
| `ean` | Código comercial cuando exista |
| `brand` | Marca normalizada |
| `presentation` | Unidad, peso o presentación original |
| `supplier_price` | Precio observado en el proveedor |
| `cost_price` | Costo real editable de Devioz |
| `suggested_price` | Precio calculado con el margen configurado |
| `price` | Precio final de venta decidido por Devioz |
| `margin_pct` | Margen personalizado opcional |
| `stock` / `min_stock` | Existencia local y alerta mínima |
| `active` | Habilitado administrativamente |
| `sale_enabled` | Autorizado para venta pública |
| `restricted` | Bloqueado para publicación y recomendaciones |
| `source_updated_at` | Fecha de la última actualización del proveedor |
| `created_at` / `updated_at` | Auditoría operativa |

`code` será estable y único, con formato derivado del origen, por ejemplo `SRC-00011604`, cuando no exista un código propio.

### 3.3 Reglas de identidad y duplicados

- La importación no eliminará fichas distintas únicamente porque compartan nombre.
- Un registro de origen se identifica por `source_product_id` y no puede importarse dos veces.
- Los duplicados exactos dentro de la misma fuente se detectan por EAN; si falta, por proveedor + nombre normalizado + presentación.
- Si el mismo EAN aparece en varios proveedores, las ofertas permanecerán separadas y se vincularán mediante una clave de comparación. Así se conserva la procedencia y se puede comparar costos sin perder registros.
- Ninguna actualización futura de proveedor reemplazará stock, costo real, precio final o estado de venta configurados por Devioz.

## 4. Migración segura

### 4.1 Prevalidación

Antes de cambiar tablas, el instalador comprobará:

- que `productos` existe y tiene registros;
- que están disponibles las tablas operativas esperadas;
- que el usuario MySQL puede crear, renombrar e indexar tablas;
- conteos de `products`, `product_images`, `inventory_movements`, `combos`, `combo_items`, `store_featured_products` y `stock_reservations`;
- espacio y motor InnoDB compatibles.

### 4.2 Respaldo y sustitución

La migración se ejecutará con registro de estado y estos puntos de control:

1. Crear una ejecución en `catalog_migrations` con fecha, versión y conteos iniciales.
2. Crear copias estructurales y de datos con prefijo `legacy_` para el inventario y todas sus tablas dependientes.
3. Verificar que cada copia tenga el mismo conteo que su tabla original. Si una verificación falla, detener el proceso antes de reemplazar nada.
4. Con las copias verificadas, retirar de la operación las relaciones antiguas y crear el nuevo esquema operativo.
5. Importar cada ficha válida de `productos` al nuevo `products`, inicialmente con `stock = 0`, `active = 0` y `sale_enabled = 0`.
6. Calcular `suggested_price = supplier_price * 1.25` cuando exista un precio válido, sin convertirlo automáticamente en precio final publicado.
7. Crear las nuevas tablas dependientes vacías y sus claves foráneas hacia el inventario nuevo.
8. Verificar conteo importado, productos omitidos y errores; guardar el informe en `catalog_migration_issues`.
9. Marcar la migración como completada. La sección de respaldo será solo lectura.

La sustitución nunca se hará con un `TRUNCATE` directo sobre tablas relacionadas. El script será idempotente: si detecta una ejecución completada de la misma versión, no duplicará datos.

### 4.3 Datos que se conservan

- usuarios y configuración;
- clientes, direcciones y favoritos compatibles;
- pedidos e ítems vendidos como instantáneas históricas;
- contenido comercial y métricas no vinculadas al inventario anterior;
- inventario, movimientos, imágenes, combos, destacados y reservas anteriores en `legacy_*`.

## 5. Estados y publicación

Un producto será visible en la tienda solo si cumple simultáneamente:

```text
active = 1
sale_enabled = 1
restricted = 0
stock > 0
price > 0
```

Estados administrativos:

- **Pendiente:** recién importado, todavía no configurado.
- **Listo:** tiene costo, precio y stock válidos, pero no está publicado.
- **Publicado:** cumple todas las condiciones de venta.
- **Sin stock:** publicado administrativamente, sin existencia disponible.
- **Restringido:** excluido de publicación e IA.

Las operaciones masivas permitirán establecer margen, precio sugerido, stock mínimo, activación y autorización de venta. Antes de guardar mostrarán el número de filas afectadas y requerirán confirmación. Nunca asignarán stock positivo sin una cantidad indicada por el administrador.

## 6. Tienda pública

### 6.1 Sistema visual

- Azul noche principal `#0B1423`.
- Azul oscuro secundario `#111C2E`.
- Turquesa `#18C7B1`.
- Verde `#4ADE80`.
- Blanco `#F8FAFC`.
- Gris claro `#CBD5E1`.
- Tarjetas blancas, radios amplios, sombras suaves, iconografía clara y contraste accesible.

### 6.2 Estructura

1. Franja superior de beneficios o avisos.
2. Encabezado oscuro con logotipo Devioz, botón de categorías, buscador amplio, cuenta y carrito.
3. Selector de entrega o recojo.
4. Banner principal administrable y adaptable.
5. Categorías visuales.
6. Ofertas.
7. Recomendaciones de IA.
8. Productos más vendidos.
9. Combos.
10. Asistente flotante.
11. Carrito lateral rápido.
12. Pie de página profesional.

Las tarjetas mostrarán imagen, nombre, presentación, precio, descuento válido, disponibilidad y botón de agregar. La página de detalle mostrará únicamente información propia de Devioz; el proveedor y el costo no serán públicos.

## 7. Administración

### 7.1 Navegación

Barra lateral azul noche con: Dashboard, Todos los productos, Inventario Devioz, Proveedores, Rentabilidad, Movimientos, Ventas, Pedidos, Promociones, Contenido, IA, Respaldo anterior y Configuración.

### 7.2 Dashboard

- productos maestros y productos publicados;
- valor del inventario;
- ventas, costos y ganancia real;
- ganancia potencial del stock;
- productos sin precio, sin costo o sin stock;
- gráfico de ventas y rentabilidad;
- productos más rentables;
- actividad y recomendaciones de IA;
- acciones rápidas para importar, activar y corregir datos.

### 7.3 Todos los productos

Tabla con búsqueda, filtros y paginación en MySQL. Columnas principales: selección, imagen, producto, origen, categoría, EAN, costo proveedor, costo Devioz, precio sugerido, precio final, margen, stock, utilidad, estado y acciones.

Filtros: origen, categoría, estado, con/sin EAN, con/sin precio, con/sin stock, margen, restringido y fecha de actualización. Permitirá ordenar por precio, stock, utilidad y actualización, editar en línea y exportar el resultado filtrado a CSV de forma segura.

## 8. Rentabilidad

- **Ganancia unitaria:** `price - cost_price`.
- **Margen:** `(price - cost_price) / price * 100` cuando `price > 0`.
- **Ganancia potencial:** ganancia unitaria por stock disponible.
- **Ganancia real:** suma de la utilidad registrada en ítems de pedidos o movimientos de salida confirmados.
- Los productos sin costo no mostrarán una ganancia falsa; aparecerán como pendientes de costo.
- Los precios de proveedor alimentan comparaciones y sugerencias, no los resultados reales de Devioz.

## 9. Inteligencia artificial

El buscador y el asistente consultarán exclusivamente productos que cumplen las reglas de publicación. El modelo recibirá un conjunto limitado de candidatos obtenido primero mediante consultas preparadas; nunca tendrá acceso directo a credenciales ni capacidad de escribir en MySQL.

Antes de presentar o preparar un carrito, el servidor validará nuevamente identificador, precio, stock, presupuesto y estado. La IA podrá proponer un carrito, pero el cliente deberá confirmarlo. Si Ollama no responde, reglas locales resolverán búsquedas por palabras, categorías, precio y presupuesto. Los productos restringidos no entrarán en candidatos ni respuestas.

## 10. Rendimiento

- Búsqueda y filtros siempre en servidor; no se cargarán los 11,604 productos en el navegador.
- Paginación pública de 24 o 48 productos y administrativa de 25, 50 o 100.
- Índices compuestos para publicación, categoría, proveedor, estado, precio y stock.
- Índices para `source_product_id`, EAN y búsqueda normalizada.
- Imágenes con carga diferida y tamaño reservado para evitar saltos visuales.
- Consultas del dashboard agregadas por rango de fechas e índices de movimientos/pedidos.
- Las operaciones masivas se procesarán por lotes para no exceder el tiempo de XAMPP.

## 11. Seguridad y validación

- Consultas preparadas para valores introducidos por el usuario.
- Protección CSRF en formularios, edición rápida y acciones masivas.
- Validación en servidor de precio, costo, margen, stock, páginas, filtros e identificadores.
- Permisos administrativos para migración, activación masiva y exportación.
- Escapado de salida HTML y protección contra fórmulas en CSV.
- Registro de auditoría para cambios masivos y publicación.
- Mensajes comprensibles si falta una tabla, columna o requisito de instalación.
- Los tokens de Ollama o integraciones no se incluirán en el repositorio ni en respuestas al navegador.

## 12. Instalación y entregables

Se entregarán dos rutas:

1. **Actualización:** script SQL/PHP que respalda la instalación existente, importa el catálogo y verifica conteos.
2. **Instalación nueva:** base completa con el catálogo maestro y el esquema final.

El ZIP final incluirá instrucciones para XAMPP, orden de importación, verificación posterior y procedimiento de recuperación desde `legacy_*`. No se cambiarán automáticamente las credenciales actuales.

## 13. Pruebas y criterios de aceptación

- La migración se detiene sin reemplazar datos si un respaldo no coincide.
- El conteo de filas operativas corresponde al catálogo válido importado y las diferencias quedan explicadas.
- Los productos migrados comienzan sin stock y sin venta pública.
- La tienda no muestra productos inactivos, sin precio, sin stock o restringidos.
- Las acciones masivas afectan únicamente la selección o filtro confirmado.
- Búsqueda, filtros y paginación responden sin transferir el catálogo completo.
- Carrito y checkout vuelven a validar stock y precio.
- Pedidos nuevos descuentan stock y registran costo y utilidad.
- Ganancia real, unitaria y potencial usan las fórmulas definidas.
- El fallback de IA funciona si Ollama está apagado y no inventa productos.
- El diseño reproduce la jerarquía de las referencias en escritorio y celular con identidad Devioz.
- PHP es compatible con PHP 8 y el SQL con MariaDB 10.4+ de XAMPP.
- Se ejecutan pruebas de sintaxis, consultas, migración, catálogo, carrito, pedidos, rentabilidad, permisos y seguridad antes de generar el ZIP final.

## 14. Fuera de alcance

- Publicar automáticamente los 11,604 productos.
- Sincronizar stock de Devioz con el stock de supermercados.
- Copiar logotipos, textos, fotografías promocionales o marca de otra tienda.
- Permitir que la IA cambie precios, stock o active productos.
- Eliminar definitivamente el inventario anterior durante esta versión.
