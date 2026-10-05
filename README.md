# Devioz Store / StockFlow

## Empieza aquí en XAMPP

La carpeta debe llamarse exactamente `stockflow`, sin espacios al final, y estar
dentro de `htdocs`. La dirección correcta es `http://localhost/stockflow/`.
Si aparece 403, ejecuta `INSTALAR_PERMISOS_XAMPP.command` después de copiarla.

La aplicación usa la base `devioz_shop_reparada`. Para una instalación nueva,
importa **solo** `database/devioz_shop_11604_completa.sql`, que crea esa base
desde cero e incluye nutrición y los métodos del checkout. Antes de repetir la
importación, exporta la base: el SQL la reemplaza y perderías cambios propios.
`upgrade_suite_completa.sql` actualiza una base antigua ya sana; importarlo en
`devioz_shop` con tablas dañadas produce errores como #1932.

Si la tienda ya abre y solo faltan las funciones nuevas, selecciona
`devioz_shop_reparada` en phpMyAdmin e importa `upgrade_nutrition.sql` y
`upgrade_plin_checkout.sql` una vez. Después crea tu cuenta con
`CREAR_ADMIN_INICIAL.command`. Nunca uses la contraseña de demostración de
versiones anteriores.

**Actualización para snacks y bebidas sin alcohol:** antes de usar esta versión, sigue [LEEME_VERSION_SIN_ALCOHOL.md](LEEME_VERSION_SIN_ALCOHOL.md). La migración adicional desactiva productos restringidos, publica los productos propios aptos con stock real y agrega nuevas fichas de bebidas con stock inicial cero.

Devioz Store es una aplicación web para administrar una tienda, construida con HTML5, CSS3, JavaScript, PHP, MySQL y XAMPP. Incluye catálogo público, inventario, ofertas, combos y control financiero.

## Funcionalidades

- Catálogo público responsive con tarjetas comerciales que muestran únicamente imagen, nombre, descripción y precio.
- Botón **Comprar** en todos los productos: agrega el artículo y abre la lista para ajustar la cantidad y pagar con Yape.
- Portada comercial renovada con productos reales del inventario, indicadores de confianza y mejor jerarquía visual.
- Galería profesional de hasta 8 imágenes por producto, con cambio automático, miniaturas, flechas, indicadores, teclado, deslizamiento táctil y vista ampliada.
- Identidad visual con el logotipo oficial proporcionado para catálogo, acceso y panel administrativo.
- Búsqueda instantánea por nombre o descripción y filtro visual por categoría.
- Filtro por categoría y modal de detalles.
- Lista de compra local con cantidades, presentaciones por unidad o paquete y total estimado.
- Compra con Yape simplificada: el sistema completa total, productos y código de pedido; el cliente solamente sube la captura para revisión administrativa.
- Detalle financiero por pedido Yape con productos, cantidades, venta, costo, ganancia y stock antes/después; al aprobar se descuenta inventario y se registra la salida.
- Inicio de sesión administrativo con contraseña cifrada.
- Dashboard con ventas, compras, ganancias, inversión, valor del inventario y alertas de stock.
- Vista de precios y rentabilidad con búsqueda, filtros, ordenamiento, paginación y selector de filas.
- Cálculo por producto de cantidad comprada, compra total, costo unitario, ganancia por unidad, margen, venta potencial y ganancia potencial.
- Registro, consulta, edición y eliminación de productos, con carga de imágenes.
- Carga múltiple de fotografías desde el panel, URLs adicionales y eliminación visual de imágenes existentes.
- Almacenamiento resistente de galerías: intenta guardar los archivos en `assets/uploads/products` y usa MySQL automáticamente cuando XAMPP no permite escribir en la carpeta.
- Catálogo público simplificado: las tarjetas muestran únicamente imagen, nombre, descripción y precio; los datos de administración permanecen en el panel.
- Costo, precio de venta, margen, stock mínimo, ofertas y six pack configurables.
- Gestión de categorías y combos sin modificar código.
- Cálculo en vivo de precio normal, ahorro y disponibilidad al crear combos; los clientes pueden agregarlos a su lista de compra.
- Historial de entradas, salidas y ajustes con fecha y hora.
- Gastos, ingresos, ganancia y método de pago (efectivo, Yape, Plin, tarjeta o transferencia).
- Notificaciones adicionales por Telegram para pedidos de Yape y efectivo, con botón de prueba desde el panel.
- Recibo digital seguro al completar la entrega, accesible desde el seguimiento, imprimible/guardable como PDF y compartible por Telegram.
- Actualización automática del stock al registrar una compra o venta.
- Filtros, paginación y estados Activo/Inactivo.
- Confirmación personalizada antes de eliminar.
- Validación en JavaScript y PHP.
- Consultas preparadas PDO, protección CSRF y escape de contenido.
- Catálogo completo importado con nombre, marca, categoría, presentación, EAN, precio regular, oferta, tienda, disponibilidad, imagen y fecha de actualización.
- Comparador de precios por supermercado y asistente de compras enriquecido con los mismos datos.
- Cuenta de cliente con direcciones, favoritos e historial de pedidos.
- Delivery por zona, cupones, reservas de stock por 30 minutos y desglose de subtotal, descuento y envío.
- Panel de estadísticas, roles de administrador/inventario/caja/atención y respaldo JSON.
- Categorías externas sincronizadas automáticamente con sus productos y conteos separados de catálogo propio/importado.
- Menú administrativo desplazable con acceso a catálogo, asistente, clientes, ventas, configuración y seguridad.
- Tienda pública estilo supermercado con identidad Devioz azul noche, turquesa y verde.
- Panel **Todos los productos** con inventario Devioz, Plaza Vea, Metro y Tottus, filtros MySQL y exportación CSV.
- Ganancia real, potencial y estimada claramente separadas.
- Asistente flotante con Ollama local y respaldo automático por reglas cuando el modelo está apagado.
- Gestión administrativa de banners y productos destacados.

## Requisitos

- XAMPP con Apache, PHP 8.0 o superior y MySQL/MariaDB.
- Navegador web moderno.

Para publicar en un hosting revisa primero `DEPLOYMENT.md`. La aplicación acepta variables de entorno para no guardar credenciales de producción en el código.

## Instalación en macOS

1. Copia el proyecto exactamente en `/Applications/XAMPP/xamppfiles/htdocs/stockflow/`.
2. Inicia **Apache Web Server** y **MySQL Database** desde XAMPP Manager.
3. Para una instalación nueva abre [phpMyAdmin](http://localhost/phpmyadmin) e importa solamente `database/devioz_shop_11604_completa.sql`. El archivo vuelve a crear `devioz_shop_reparada` e incluye nutrición y checkout; respalda antes cualquier base con ese nombre.
4. Espera las consultas finales: `source_rows` y `operational_rows` deben ser `11604`, y la última fila de `catalog_migrations` debe estar `completed` con `source_count=11604` e `imported_count=11604`.
5. Ejecuta `CREAR_ADMIN_INICIAL.command` desde Terminal. El asistente solicita la contraseña inicial sin mostrarla, la convierte a un hash con PHP y se detiene si ya existe un administrador. No hay una contraseña predeterminada.
6. Abre [http://localhost/stockflow](http://localhost/stockflow).

No importes después los SQL antiguos sobre una instalación nueva: el archivo completo contiene el catálogo fuente reparado, el esquema final y cada migración necesaria una sola vez. Las instrucciones completas están en `LEEME_CATALOGO_11604.txt`.

### Actualizar una instalación existente

1. Exporta un respaldo completo de `devioz_shop_reparada`.
2. Confirma que `productos` contiene exactamente `11604` filas. Si la instalación anterior ya tiene `store_settings.stockflow_schema_marker=catalogo_11604`, el instalador lo valida directamente.
3. Ejecuta `INSTALAR_CATALOGO_11604.command`. El instalador localiza MySQL de XAMPP, solicita las credenciales sin guardarlas y valida el esquema StockFlow antes de importar `database/upgrade_catalogo_maestro_11604.sql`. En una instalación StockFlow legítima anterior al marcador, valida una huella independiente de 12 tablas y 36 columnas, comprueba también las `11604` filas y solicita escribir exactamente el nombre de la base para inscribir el marcador de forma no destructiva. Un nombre o huella que no coincida se rechaza.
4. Si eliges otra base, escribe su nombre exactamente en la confirmación adicional; de lo contrario el instalador se detiene antes de conectar.
5. Ante cualquier diferencia, detente e inspecciona `catalog_migration_issues`; no actives productos ni repitas la migración a ciegas.

La migración conserva los datos anteriores en tablas `legacy_*`. Revísalos en modo de solo lectura desde `admin/respaldo_anterior.php`; no modifiques esas instantáneas.

## Instalación en Windows

1. Descomprime la carpeta `stockflow`.
2. Copia la carpeta completa dentro de `C:\xampp\htdocs\`.
3. En el panel de XAMPP, activa **Apache** y **MySQL**.
4. Para una instalación nueva importa solamente `database/devioz_shop_11604_completa.sql` desde [phpMyAdmin](http://localhost/phpmyadmin).
5. Abre [http://localhost/stockflow](http://localhost/stockflow).

Para actualizar en Windows, respalda `devioz_shop_reparada`, verifica primero las `11604` filas y ejecuta el mismo procedimiento de validación/enrollment documentado en `LEEME_CATALOGO_11604.txt`; el marcador solo se inscribe después de confirmar explícitamente el nombre de la base.

## Acceso administrativo

- URL: [http://localhost/stockflow/login.php](http://localhost/stockflow/login.php)
El SQL no incluye credenciales reutilizables. Después de una instalación nueva,
ejecuta `CREAR_ADMIN_INICIAL.command` desde Terminal/XAMPP y define una
contraseña fuerte (mínimo 12 caracteres con mayúscula, minúscula, número y
símbolo). El asistente la hashea con PHP, rechaza un administrador ya existente
y elimina su archivo temporal de credenciales al terminar. No hay una contraseña
predeterminada.

## Configuración de MySQL

La conexión se encuentra en `config/database.php` y utiliza la configuración habitual de XAMPP:

```php
DB_HOST = localhost
DB_PORT = 3306
DB_NAME = devioz_shop_reparada
DB_USER = root
DB_PASS = (vacío)
```

Si configuraste una contraseña para el usuario `root`, cambia `DB_PASS` en ese archivo.

## Activación segura del catálogo maestro

Los `11604` productos maestros se importan desactivados, sin venta, precio ni stock operativo. Desde **Todos los productos**, revisa restricciones, costo, precio y stock antes de activar y publicar lotes pequeños. Un artículo solo puede venderse cuando está activo, habilitado para venta, no restringido y tiene precio y stock positivos.

## Ollama opcional

El asistente usa reglas deterministas si Ollama no está disponible. Para IA local, inicia Ollama con el modelo predeterminado `llama3.2:3b` y comprueba `http://127.0.0.1:11434/api/tags`. Puedes cambiarlo con `SHOPPING_AI_MODEL`; no es un requisito para instalar ni verificar el catálogo.

## Estructura principal

```text
stockflow/
├── admin/              Dashboard, productos, categorías, combos y movimientos
├── api/                Búsqueda dinámica en formato JSON
├── assets/             CSS, JavaScript e imágenes
├── config/             Conexión PDO con MySQL
├── database/           SQL integrado de devioz_shop y migraciones
├── includes/           Funciones y plantillas compartidas
├── index.php           Catálogo público
├── media.php           Entrega segura de imágenes almacenadas en MySQL
├── login.php           Acceso administrativo
└── logout.php          Cierre de sesión
```

## Cómo registrar una compra o venta

1. Ingresa al panel y abre **Entradas y salidas**.
2. Selecciona producto, tipo, presentación y cantidad.
3. Para una compra registra el costo por unidad o paquete.
4. Para una venta confirma el precio y el método de pago.
5. El sistema calcula gasto, ingreso, ganancia y nuevo stock antes de guardar.

## Cómo activar Yape en el catálogo

1. Ingresa al panel administrativo y abre **Pagos con Yape**.
2. Revisa el titular y el QR activo; puedes registrar también el número y WhatsApp.
3. El cliente agrega productos, paga el total mostrado y solamente sube la captura del comprobante.
4. El sistema recalcula los precios, guarda el total correcto y genera automáticamente la referencia del pedido.
5. Abre **Pedidos Yape** para ampliar la captura y aprobar o rechazar el pago.

La captura y el código de operación quedan en estado **pendiente** hasta que el administrador confirme en su aplicación Yape que el abono realmente fue recibido. Sin una API oficial de Yape, una imagen no debe aprobarse automáticamente.

## Solución de problemas

### Error de conexión a MySQL

Comprueba que MySQL esté activo y que hayas importado `database/devioz_shop_11604_completa.sql`. Revisa también que `DB_NAME` apunte a `devioz_shop_reparada` y que las credenciales de `config/database.php` o del entorno sean correctas.

### El catálogo no muestra 11,604 productos

No publiques productos. Ejecuta las tres consultas de verificación de `LEEME_CATALOGO_11604.txt` y revisa `catalog_migration_issues`. Un conteo distinto requiere corregir la fuente o la incidencia antes de reintentar.

### Error 404

Confirma que la carpeta se llame exactamente `stockflow` y esté directamente dentro de `htdocs`.

### La página carga sin estilos

Accede mediante `http://localhost/stockflow`; no abras los archivos PHP directamente desde Finder o el explorador.

## Tecnologías

- HTML5 y CSS3
- JavaScript ES6 y Fetch API
- PHP 8 con PDO
- MySQL/MariaDB
- XAMPP
# Cambios incluidos en esta entrega

- Catálogo público: solo muestra productos con stock, precio válido y visibilidad activa; si el stock llega a cero desaparecen.
- Nutrición: cada producto puede marcarse como comida, no aplica o revisar, con kcal por 100 g/envase, fuente y confianza. Si falta dato real, se muestra "Sin información".
- Checkout: recorrido por pasos para resumen, entrega, pago y confirmación. Soporta efectivo, Yape, Plin y opción de tarjeta preparada para Culqi.
- Administración: bandeja de pendientes, estados simples Visible/Oculto/Sin stock, edición rápida de precio/stock/visibilidad y cálculo seguro para combos.

## Migraciones nuevas

En instalaciones existentes importa:

1. `database/upgrade_nutrition.sql`
2. `database/upgrade_plin_checkout.sql`

La instalación nueva `database/devioz_shop_11604_completa.sql` ya las incluye.
No vuelvas a importarlas después de instalar con ese archivo.

## Tarjetas con Culqi

Define `CULQI_PUBLIC_KEY`, `CULQI_PRIVATE_KEY`, `CULQI_WEBHOOK_SECRET` y `CULQI_MODE` en el servidor. La llave privada no se imprime en HTML; el navegador solo recibe la llave pública.
