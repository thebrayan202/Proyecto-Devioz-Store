# Hosting e incorporación de catálogos externos

## Qué está preparado
- PHP consulta una API de IA por HTTPS desde el hosting; tu Mac puede estar apagada.
- Proveedor OpenAI (Responses) configurable, Ollama opcional y modo básico sin IA.
- Selector de tienda y sede. Plaza Vea se registra vacía, pendiente de cargar datos.
- Ofertas externas separadas del inventario y de los pedidos Devioz.
- Importe total, saldo y reserva para envío u otros gastos.
- Importador JSON privado en Administración → Catálogos para compras.
- ID externo por fuente para actualizar sin duplicados; GTIN opcional para futura
  equivalencia exacta de productos, presentación y fecha de verificación UTC.
- Stock desconocido se muestra como desconocido. No se inventan existencias.
- Precios externos con más de 48 horas se excluyen (plazo configurable).

## Instalar en tu hosting actual
1. Haz copia de seguridad de los archivos y de tu base de datos.
2. Sube los archivos nuevos y modificados de esta versión, listados abajo.
   Conserva `config/database.php`, tu configuración y tus archivos subidos.
3. En phpMyAdmin selecciona la base de datos de tu tienda e importa
   `database/upgrade_shopping_sources.sql`. No vuelvas a importar stockflow.sql.
   La migración es repetible, crea tablas nuevas y no modifica pedidos/productos.
4. Abre el panel de administración → Catálogos para compras.
5. Abre `asistente_compras.php` desde tu tienda para comprobar el modo básico.

Requisitos: PHP 8+, PDO MySQL y mbstring (ya usados por el proyecto). Para IA:
cURL, certificados TLS válidos y salida HTTPS a api.openai.com:443. El hosting
no necesita ejecutar modelos ni tener GPU. La llamada tarda como máximo 25 s.
Configura APP_ENV=production y APP_DEBUG=0 en el servidor.

## Activar IA
Opción A: variables de entorno del hosting:
```
SHOPPING_AI_PROVIDER=openai
SHOPPING_AI_MODEL=ID_DEL_MODELO_DE_TU_CUENTA
OPENAI_API_KEY=TU_CLAVE_API
```
Opción B, si el panel no permite variables:
- Copia `config/shopping_agent.local.example.php` a
  `config/shopping_agent.local.php` en el servidor.
- Completa el ID exacto de un modelo habilitado en tu cuenta que admita Responses
  y Structured Outputs, y tu clave API.
- El archivo local tiene prioridad sobre las variables para los campos presentes.
  No lo publiques ni lo incluyas en futuros ZIP. El directorio config tiene
  `Require all denied` para Apache; si usas Nginx, bloquea el acceso HTTP a config.

No se incluye clave, modelo elegido, saldo API ni servicio externo activado.
La configuración no confirma una conexión exitosa: prueba una petición breve
una vez instalada. La API puede tener cargos según tu proveedor/modelo.
Por defecto hay un máximo global de 100 intentos de IA por día UTC y 10 por sesión;
se contabilizan también los intentos fallidos. Puedes reducir daily_requests
(incluso a 0) en shopping_agent.local.php. El límite no es un presupuesto monetario.
No se envía la base completa: solo texto de la petición y hasta 100 productos
candidatos con nombre, categoría, presentación, precio e ID. No se envían pagos.
El modelo solo selecciona IDs; el servidor valida IDs, stock e importes.
Si falla la conexión o se alcanza el límite, se indica el paso a modo básico.

Documentación oficial usada:
- https://developers.openai.com/api/docs/quickstart
- https://developers.openai.com/api/docs/guides/structured-outputs

## Cómo actualizar catálogos después de la instalación
La base entregada ya está integrada en `devioz_shop_integrada.sql`. Si después
quieres cargar otra sede o una actualización parcial, adapta sus filas al siguiente
contrato JSON y cárgalas desde Administración → Catálogos para compras.

Ejemplo exclusivamente ilustrativo, con precio inventado; no es una oferta real:
```json
[
  {
    "external_id": "EJEMPLO-001",
    "gtin": null,
    "name": "Arroz de ejemplo",
    "brand": "Marca de ejemplo",
    "category": "Abarrotes",
    "presentation": "Bolsa 1 kg",
    "price": "4.50",
    "regular_price": "5.20",
    "discount_pct": 13.46,
    "product_url": "https://tienda.example/producto",
    "image_url": "https://tienda.example/imagen.webp",
    "supermarket": "Tienda de ejemplo",
    "stock": null,
    "available": true,
    "verified_at": "2026-01-01T12:00:00Z"
  }
]
```
La fecha ilustrativa está vencida: usa la fecha real de verificación de tus datos,
no la fecha de importación. No se instala ninguna oferta de ejemplo automáticamente.

Campos obligatorios: external_id, name, category, presentation, price, available,
verified_at. `price` es texto decimal en soles, sin símbolo, hasta dos decimales.
`stock` es entero >= 0 o null si no se conoce. `available` es un booleano.
`verified_at` es UTC con formato YYYY-MM-DDTHH:MM:SSZ, no admite fechas futuras.
GTIN es opcional (8, 12, 13 o 14 dígitos; conserva ceros iniciales).
También son opcionales `brand`, `regular_price`, `discount_pct`, `product_url`,
`image_url` y `supermarket`. Las URL deben usar HTTP o HTTPS.
Categorías: Snacks, Galletas, Dulces y chicles, Bebidas, Abarrotes, Lácteos,
Frutas y verduras. Alcance: alimentos y bebidas sin alcohol.

La carga admite 2 MB / 1000 filas, valida todo antes de escribir y usa transacción.
Una fila inválida cancela toda la carga. Se rechazan IDs duplicados y datos más
antiguos que los ya guardados. Fuente + ID externo identifica una oferta.
Las filas ausentes de una carga parcial se conservan hasta su vencimiento;
para retirar una oferta informa available=false. Usa otra fuente para otra sede.
Se muestran hasta 500 candidatos por categoría/tienda; con más datos solicita
una categoría más específica. La IA solo procesa hasta 100 candidatos por pedido.

## Actualizaciones futuras
La importación no hace descarga automática, scraping ni compra externa. Los datos
se actualizan al volver a importar el SQL de integración o al cargar JSON desde
el panel. El comparador muestra coincidencias por búsqueda; confirma que tamaño y
presentación sean equivalentes antes de comparar.

## Uso y límites
Elige tienda, presupuesto, reserva para gastos y máximo por producto. En IA,
puedes indicar preferencias de productos; las cantidades las calcula el sistema
con el máximo por producto, no se extraen cantidades exactas del texto.
Se favorece variedad por rondas; no garantiza la combinación matemáticamente
óptima. No considera promociones condicionadas, descuentos por tarjeta, packs
ni combos. La reserva no calcula el envío real.
Para Devioz, puedes sustituir Mi lista y seguir al pago existente. Para tiendas
externas se imprime una lista orientativa; sus IDs nunca se insertan en el carrito
Devioz. No se realiza ninguna compra externa automáticamente.

## Archivos de esta actualización
Modificados: config/shopping_agent.php, includes/shopping_agent.php,
asistente_compras.php, includes/admin_header.php y ASISTENTE_COMPRAS.md.
Nuevos: config/shopping_agent.local.example.php, includes/shopping_ai.php,
includes/shopping_sources.php, admin/fuentes_compras.php,
database/upgrade_shopping_sources.sql, HOSTING_Y_CATALOGOS.md y tests/.
Si vienes del proyecto anterior al asistente, sube también el enlace en
includes/public_header.php.

## Verificación
Se incluyen pruebas de regresión ejecutables: `php tests/shopping_agent_test.php`.
Comprueban presupuesto, stock, datos externos, importación y respuestas IA inválidas.
No requieren conexión a la API ni realizan compras. Las comprobaciones de SQL,
conectividad API y recorrido completo necesitan tu PHP/MySQL y configuración real.
Consulta el resultado de validación indicado junto al archivo entregado.

Resultado local: 9 archivos PHP analizados con un parser PHP, sin errores de
sintaxis. Cambios acotados a los archivos listados y revisión estática de límites,
CSRF, permisos y separación de carritos. Este entorno no dispone de PHP/MySQL:
las pruebas PHP incluidas no se han ejecutado, ni se ha verificado una API real.
