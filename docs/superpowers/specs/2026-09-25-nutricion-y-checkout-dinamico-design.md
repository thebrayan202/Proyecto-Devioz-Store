# Nutrición verificable y checkout dinámico

**Fecha:** 2026-09-25  
**Estado:** diseño aprobado en conversación; pendiente de revisión del documento  
**Proyecto:** StockFlow / Devioz Store

## 1. Objetivo

Agregar información calórica útil al catálogo y al asistente de compras sin
inventar datos, y reemplazar el formulario largo de pago por un recorrido corto
y progresivo. El cliente debe poder entender cuántas calorías aporta una
propuesta de compra y completar un pedido con menos decisiones simultáneas.

El resultado se considerará correcto cuando:

- solo los productos aptos para consumo humano participen en cálculos
  nutricionales;
- cada cifra indique su fuente y si es verificada, una referencia aproximada o
  no está disponible;
- el asistente calcule calorías por producto y para el conjunto de la propuesta
  usando datos guardados en la base local;
- el pago se complete en cuatro pasos claros, con total actualizado y sin
  debilitar las comprobaciones actuales de stock, precio, cupón y entrega;
- efectivo, Yape y Plin funcionen como métodos reales; tarjeta quede indicada
  como integración posterior y no como un pago ficticio.

## 2. Alcance y límites

### Incluido

- Clasificación explícita entre alimento humano y producto no alimentario.
- Ficha nutricional por producto, con energía, porción, macronutrientes, fuente
  y fecha de verificación.
- Consulta administrativa por EAN para productos envasados.
- Referencias para alimentos genéricos basadas en las Tablas Peruanas de
  Composición de Alimentos del INS.
- Captura y corrección manual a partir de la etiqueta real del producto.
- Calorías por artículo, por cantidad y total de la propuesta del asistente.
- Checkout en cuatro pasos: resumen, entrega, pago y confirmación.
- Efectivo, Yape y Plin con comportamiento específico por método.
- Diseño adaptable a celular, navegación por teclado y mensajes de error en el
  paso correspondiente.

### No incluido en esta fase

- Diagnóstico médico, dietas terapéuticas o afirmaciones de salud.
- Metas calóricas personales basadas en edad, peso o condiciones médicas.
- Inventar nutrientes mediante un modelo de lenguaje.
- Sustituir el control final del administrador para comprobantes Yape o Plin.

## 3. Fuentes y niveles de confianza

El sistema aplicará esta prioridad:

1. **Etiqueta verificada:** valores copiados de la etiqueta del producto y
   revisados desde administración. Es la fuente principal para un producto
   envasado concreto.
2. **Open Food Facts por EAN:** útil para precargar alimentos envasados. El dato
   se guarda localmente y debe conservar la referencia, fecha y estado de
   revisión. La API no se consultará durante la navegación pública.
3. **INS/CENAN:** referencia preferida para alimentos genéricos o preparaciones
   peruanas con equivalencia confirmada por el administrador.
4. **Sin información:** si no existe una coincidencia confiable, el producto no
   aporta una cifra al total. La interfaz dirá cuántos artículos quedaron sin
   dato.

Estados visibles:

- `Verificado`: etiqueta o revisión administrativa confirmada.
- `Referencia aproximada`: alimento equivalente de una tabla reconocida.
- `Sin información`: no se dispone de una base suficiente.
- `No aplica`: artículo no destinado al consumo humano.

Fuentes de referencia:

- Open Food Facts API: https://github.com/openfoodfacts/openfoodfacts-server/blob/main/docs/api/index.md
- Tablas Peruanas de Alimentos del INS: https://tablasperuanas.ins.gob.pe/
- FoodData Central del USDA, como respaldo para alimentos genéricos que no
  existan en la tabla peruana: https://fdc.nal.usda.gov/api-guide/

## 4. Modelo de datos nutricional

Se añadirá una tabla `product_nutrition` con una fila vigente por producto:

| Campo | Propósito |
|---|---|
| `product_id` | Relación única con `products` |
| `applicability` | `food`, `non_food` o `review` |
| `energy_kcal_100g` | Energía normalizada por 100 g o 100 ml |
| `serving_size` / `serving_unit` | Tamaño y unidad de la porción declarada |
| `energy_kcal_serving` | Energía calculada o declarada por porción |
| `protein_g`, `carbohydrate_g`, `fat_g` | Macronutrientes por 100 g o 100 ml |
| `source_type` | `label`, `open_food_facts`, `ins`, `usda` o `manual` |
| `source_ref` | EAN, código de tabla o referencia legible |
| `confidence` | `verified` o `reference` |
| `verified_at`, `verified_by` | Trazabilidad de la revisión |
| `updated_at` | Vigencia del dato local |

Los campos nutricionales serán anulables. Cero será un valor real, no el
equivalente de “sin dato”. La tabla no cambiará precios, stock ni visibilidad.

La clasificación automática solo propondrá un estado inicial. Categorías como
limpieza, higiene, mascotas y artículos del hogar quedarán en `non_food`;
categorías ambiguas quedarán en `review`. Un administrador podrá corregirla.
Alimento para mascotas no contará como alimento humano.

## 5. Administración nutricional

El formulario de producto añadirá una sección “Información nutricional” solo
cuando corresponda. Permitirá:

- marcar alimento, no alimentario o pendiente de revisión;
- buscar por EAN y previsualizar una coincidencia antes de guardarla;
- seleccionar un alimento genérico del INS cuando sea realmente equivalente;
- copiar los datos de la etiqueta y marcarlos como verificados;
- ver fuente, fecha y nivel de confianza;
- limpiar una relación incorrecta sin borrar el producto.

La importación externa será una acción administrativa explícita. Tendrá tiempo
de espera, límite de peticiones, identificación del cliente y caché local. Una
respuesta externa nunca sobrescribirá silenciosamente un dato verificado de
etiqueta.

## 6. Cálculo y presentación de calorías

Un servicio PHP independiente normalizará los datos y calculará:

- calorías por porción;
- calorías de la presentación completa cuando el peso o volumen sea conocido;
- calorías según la cantidad seleccionada;
- suma conocida de una propuesta o carrito;
- cobertura: número de artículos calculados y número sin información.

La presentación o peso extraído del nombre podrá ayudar a sugerir una cantidad,
pero no convertirá el resultado en `Verificado`. Si no se puede determinar el
peso consumible, se mostrará la cifra por porción o por 100 g en lugar de
inventar el total del envase.

El asistente de IA recibirá únicamente el resumen nutricional ya calculado. La
IA podrá ordenar o explicar opciones, pero no será la fuente de calorías. Los
totales se recalcularán en PHP después de cualquier selección de la IA.

Ejemplo de salida:

> Total conocido: 1 240 kcal · 5 de 6 productos con información. Una bebida no
> tiene dato verificado.

Se añadirá una nota breve: los valores son informativos y pueden variar según
la preparación o la porción consumida.

## 7. Checkout dinámico

El checkout conservará el diálogo actual y su validación del servidor, pero lo
dividirá visualmente en cuatro pasos:

### Paso 1 — Revisar compra

- Productos, cantidades, subtotales y total provisional.
- Edición de cantidades sin cerrar el checkout.
- Reconciliación de stock y precio antes de avanzar.

### Paso 2 — Recibir o recoger

- Nombre y celular.
- Recojo o zona de entrega mediante tarjetas claras.
- Dirección y referencia solo si hay envío.
- Cupón y cotización en vivo con subtotal, descuento, envío y total.

### Paso 3 — Elegir pago

- **Efectivo:** pago exacto o monto entregado, con vuelto inmediato.
- **Yape:** QR o número configurado, carga y vista previa del comprobante.
- **Plin:** QR o número propios, carga y vista previa del comprobante.
- **Tarjeta:** Culqi Custom Checkout en modo integración o producción según la
  configuración del comercio. Los datos de tarjeta se tokenizan en Culqi y
  nunca pasan por el servidor de StockFlow.

Yape y Plin compartirán el componente seguro de carga de comprobante, pero
mantendrán configuración, etiqueta y cuenta separadas. Si un método no está
configurado, no aparecerá como seleccionable.

### Paso 4 — Confirmar y seguir

- Resumen final de productos, entrega, descuento, total y método.
- Casilla de confirmación del pedido.
- Creación del pedido solo después de una nueva validación en el servidor.
- Código, PIN, botón para copiarlos y enlace al seguimiento.

Habrá una barra de progreso, botones Atrás/Continuar y persistencia temporal de
los campos no sensibles mientras el diálogo permanezca abierto. Los errores no
cerrarán el diálogo ni borrarán la información ya válida.

## 8. Servidor, seguridad y compatibilidad

- `checkout_quote.php` seguirá siendo la autoridad para precios, stock, cupón,
  entrega y total.
- `yape_order.php` ampliará la lista permitida a `efectivo`, `yape` y `plin` y
  conservará transacción, reservas e instantáneas del pedido.
- Los pagos Culqi se crearán como pendientes y solo pasarán a aprobados después
  de consultar el cargo con la API usando la llave privada o procesar un webhook
  autenticado e idempotente. El retorno del navegador no aprobará pedidos.
- La llave pública Culqi podrá enviarse al navegador. La llave privada y el
  secreto de webhook vivirán en variables de entorno o configuración local
  excluida del paquete; nunca en SQL, HTML o JavaScript versionado.
- El esquema ampliará el método de pago donde sea necesario sin renombrar las
  tablas históricas `yape_orders` para evitar una migración destructiva.
- Comprobantes Yape y Plin usarán las restricciones existentes de formato,
  tamaño, almacenamiento y acceso administrativo.
- Se preservarán CSRF, límites de frecuencia, escape de salida y validación de
  datos tanto en cliente como en servidor.
- Si JavaScript falla, el carrito no deberá crear un pedido incompleto.

## 9. Componentes previstos

- `includes/nutrition.php`: clasificación, normalización y cálculos puros.
- `api/product_nutrition_lookup.php`: consulta administrativa controlada.
- `admin/producto_form.php` y `admin/producto_guardar.php`: edición y guardado.
- `includes/shopping_sources.php`, `includes/shopping_agent.php` y
  `asistente_compras.php`: carga y presentación de datos nutricionales.
- `api/cart_reconcile.php`: resumen nutricional del carrito ya reconciliado.
- `includes/public_cart.php`: estructura del recorrido de pago.
- `assets/js/app.js`: máquina de estados del checkout y actualización dinámica.
- `api/checkout_quote.php` y `api/yape_order.php`: validación final y Plin.
- `includes/functions.php` y configuración administrativa: cuentas Yape/Plin.
- `includes/culqi.php`, `api/culqi_charge.php` y `api/culqi_webhook.php`:
  configuración, cargos, verificación e idempotencia de tarjeta.
- migración SQL idempotente para nutrición y configuración de Plin.

Las reglas nutricionales quedarán fuera del código de interfaz. El checkout
usará un estado explícito (`review`, `delivery`, `payment`, `confirmation`) en
lugar de depender de qué elementos estén visibles.

## 10. Errores y degradación

- Sin conexión a fuentes nutricionales: se conserva el dato local y se permite
  edición manual.
- EAN sin coincidencia: se informa “Sin información”; no se busca una
  coincidencia débil automáticamente.
- Datos incompletos: se calcula únicamente lo sustentado y se informa la
  cobertura.
- Cambio de stock o precio: el checkout regresa al resumen e identifica la
  línea afectada.
- Método de pago sin configurar: se oculta y se conserva al menos efectivo.
- Culqi no configurado o inaccesible: tarjeta se oculta o informa el fallo sin
  crear un pedido pagado; efectivo, Yape y Plin siguen disponibles.
- Error al subir comprobante: se mantiene el resto del formulario y se permite
  reintentar.

## 11. Pruebas de aceptación

### Nutrición

- Un producto no alimentario nunca muestra ni suma calorías.
- Un EAN conocido puede precargar datos, pero no sobrescribe una etiqueta
  verificada.
- Cero y dato ausente se distinguen correctamente.
- Los cálculos por 100 g, porción, presentación, cantidad y total usan
  redondeo consistente.
- Una propuesta mixta muestra suma conocida y cobertura, no un total engañoso.
- La IA no puede introducir un identificador o cifra fuera del catálogo
  nutricional validado.

### Checkout

- No se puede avanzar con datos requeridos inválidos.
- Atrás/Continuar conserva la información correcta.
- Cambiar entrega o cupón actualiza el total y vuelve a validar el pedido.
- Efectivo calcula vuelto; Yape y Plin requieren comprobante cuando están
  configurados.
- Un método no configurado no se puede enviar alterando el navegador.
- El servidor rechaza cambios de precio, stock o total entre cotización y
  confirmación.
- Ningún callback del navegador puede aprobar un pago Culqi sin confirmación
  servidor a servidor; webhooks repetidos no duplican pedidos ni movimientos.
- El pedido creado conserva método, comprobante, código, PIN y seguimiento.
- El flujo funciona en móvil, teclado y lector de pantalla básico.

## 12. Orden de implementación

1. Migración y servicio nutricional local.
2. Gestión administrativa y consulta controlada de fuentes.
3. Calorías en catálogo, carrito y asistente.
4. Checkout visual en cuatro pasos sin cambiar todavía los métodos.
5. Configuración y soporte de Plin.
6. Culqi Custom Checkout, cargo servidor a servidor y webhook idempotente.
7. Pruebas integrales, revisión responsive y paquete final actualizado.

Este orden permite validar primero la calidad de los datos y luego cambiar la
experiencia de pago conservando las comprobaciones existentes.

## 13. Simplificación de la administración

Las mejoras administrativas aprobadas se implementarán como una tercera fase,
después de estabilizar nutrición y checkout. No se añadirán módulos nuevos al
menú; se simplificarán los que ya quedaron como esenciales.

### Bandeja de acciones pendientes

El inicio mostrará una sola lista priorizada con acciones concretas:

- pedidos nuevos o pagos por revisar;
- productos con stock bajo;
- productos sin precio de venta válido;
- alimentos pendientes de clasificación o sin datos nutricionales;
- productos visibles con imagen faltante.

Cada fila tendrá una acción directa y un enlace a la vista ya filtrada. Los
avisos informativos no competirán visualmente con los que impiden vender.

### Estados simples de producto

La administración usará tres etiquetas comprensibles:

- `Visible`: tiene stock, precio válido y no está oculto manualmente;
- `Oculto`: fue retirado manualmente aunque pueda tener stock;
- `Sin stock`: se oculta automáticamente hasta reponerlo.

Los campos técnicos internos se conservarán para compatibilidad, pero el
usuario no tendrá que decidir entre varios interruptores equivalentes.

### Edición rápida

La lista de productos permitirá cambiar precio, stock, estado visible y stock
mínimo sin abrir cada ficha. Cada cambio se guardará individualmente, mostrará
éxito o error en la fila y volverá a calcular el estado resultante. Nombre,
categoría, imagen y nutrición seguirán en la ficha completa para evitar errores
en una tabla masiva.

### Asistente de combos

La creación de combos tendrá tres pasos:

1. Buscar y seleccionar productos con stock.
2. Definir cantidades y ver costo, precio sugerido y disponibilidad máxima.
3. Escribir nombre, precio final, imagen y confirmar publicación.

El sistema impedirá publicar un combo vacío, restringido o formado por
componentes sin stock suficiente. La disponibilidad se seguirá derivando de
los componentes reales.

### Inicio orientado a decisiones

El panel principal conservará únicamente:

- ventas de hoy;
- pedidos pendientes;
- pagos por revisar;
- productos por reponer;
- bandeja de acciones pendientes;
- accesos rápidos a Nuevo producto, Reponer stock y Crear combo.

Las estadísticas avanzadas permanecerán en Herramientas avanzadas. El inicio
no mostrará gráficos decorativos ni métricas que no conduzcan a una acción.

### Aceptación de la simplificación

- El administrador puede resolver las tareas urgentes desde el inicio.
- Un estado de producto se entiende sin conocer campos técnicos.
- Precio y stock se editan desde la lista con validación del servidor.
- El asistente de combos muestra el límite real antes de publicar.
- El panel funciona correctamente sin estadísticas históricas disponibles.

## 14. Entregas independientes

Para reducir riesgo, el trabajo se dividirá en tres entregas verificables:

1. **Nutrición:** datos, administración, cálculos y asistente de compras.
2. **Checkout:** recorrido de cuatro pasos, Yape, efectivo y Plin.
3. **Administración simple:** pendientes, estados, edición rápida, combos e
   inicio operativo.

Cada entrega tendrá migración idempotente, pruebas propias y compatibilidad con
los datos existentes. El paquete final reunirá las tres una vez aprobadas las
pruebas de regresión.
