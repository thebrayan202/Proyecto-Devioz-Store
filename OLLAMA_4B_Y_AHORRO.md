# Ollama 4B, recarga del formulario y cálculo de ahorro

## La pantalla de Chrome
ERR_CACHE_MISS y «Confirmar reenvío del formulario» aparecen al intentar recuperar
una página generada por POST. La captura muestra localhost: estás abriendo la copia
de tu Mac. Vuelve a escribir http://localhost/stockflow/asistente_compras.php en
la barra para abrir un GET limpio.
Esta versión guarda la propuesta en sesión y redirige con HTTP 303 antes de
mostrarla (POST/Redirect/GET). Recargar la página de resultado no repite la llamada
IA ni envía el formulario. Se guardan 5 propuestas por sesión durante 15 minutos.
La propuesta guardada no es una reserva: pulsa Preparar mi compra para actualizar
precios/stock antes de continuar. El pago mantiene su validación habitual.

## Activar Qwen3 4B en tu Mac
Ollama es el programa; qwen3:4b es el modelo de aproximadamente 4 mil millones de
parámetros. En Terminal:
```
ollama pull qwen3:4b
ollama list
```
Abre la aplicación Ollama y mantenla ejecutándose. Si usas solo la instalación
CLI y no está iniciado el servicio, ejecuta `ollama serve` en otra terminal.
No ejecutes un segundo servidor si la aplicación ya lo tiene abierto.
Copia `config/shopping_agent.ollama4b.example.php` a
`config/shopping_agent.local.php`. Conserva model=qwen3:4b y provider=ollama.
No hace falta una clave OpenAI para este modo.

PHP de XAMPP necesita cURL y las tablas de la migración
`database/upgrade_shopping_sources.sql` para contabilizar los intentos de IA.
Importa esa migración una vez en la base actual; no reimportes stockflow.sql.
El indicador «configurada» no comprueba por sí solo que el modelo esté descargado.
Prueba «Quiero agua y galletas, sin chicles» en el asistente.
Si regresa a modo básico, revisa Ollama abierto, modelo instalado, cURL habilitado,
migración importada y límites diario/sesión. No se ha instalado nada en tu Mac
mediante este ZIP ni se ha probado la conexión con tu equipo.

## Si lo subes al hosting
localhost siempre apunta al equipo donde se ejecuta PHP. Si PHP está en hosting,
no apunta a la Mac. Necesitas Ollama en ese mismo servidor (si el proveedor permite
ejecutarlo) o un servidor propio de Ollama accesible mediante un proxy HTTPS con
autenticación. Un hosting que solo ejecute PHP no ejecutará el modelo por copiar
estos archivos. Elige entonces el proveedor OpenAI ya disponible o un servidor
adecuado para Ollama. No se incluye un servidor remoto ni se publica el de tu Mac.
La configuración permite `ollama_url` y `ollama_token` para un endpoint propio
HTTPS que acepte Bearer en el proxy y ofrezca /api/chat. No expongas directamente
el puerto local de Ollama sin autenticación. No se facilita un túnel público.

## Flujo de recomendaciones
- Petición + categoría → productos candidatos con precios actuales.
- Qwen3:4b devuelve IDs permitidos, sin decidir importes ni escribir SQL.
- PHP valida los IDs y calcula cantidades y total dentro del presupuesto.
- Se usa think=false, salida limitada y keep_alive=5m para evitar trabajo adicional
  y reutilizar el modelo. La rapidez depende del equipo y de si el modelo está frío.
- Una selección válida se reutiliza durante 5 minutos solo en la misma sesión y
  si coinciden petición, catálogo (incluidos precios/stock), proveedor y modelo.
- Los resultados incompletos o inválidos pasan a modo básico indicado en pantalla.
- No extrae cantidades exactas del texto: usa Máximo por producto. No garantiza
  satisfacer todas las categorías pedidas si el presupuesto no alcanza.

## Cuánto puede ahorrar
Se muestra saldo del presupuesto, pero no se lo llama ahorro.
Puedes ingresar un precio de referencia de la misma lista (opcional).
Diferencia = referencia ingresada − total de la propuesta.
Porcentaje = diferencia / referencia × 100.
Solo es ahorro comparable si coinciden productos, presentaciones y cantidades;
no incluye envío y el precio ingresado no está verificado por el sistema.
Ejemplo hipotético: la misma lista cuesta S/ 50 en la referencia y S/ 43 aquí:
la diferencia es S/ 7 (14%). No es una promesa ni un dato real de Plaza Vea.
Sin referencia, aparece «pendiente de precios comparables».

Ollama local evita llamadas a la API comercial para esas recomendaciones, pero
no elimina electricidad, equipo o alojamiento. No hay un porcentaje de ahorro
operativo demostrable sin medir solicitudes, proveedor y costos de ejecución.

Fuentes oficiales:
- https://ollama.com/library/qwen3:4b
- https://docs.ollama.com/api/chat
- https://docs.ollama.com/faq

## Actualizar desde la versión de hosting
Sube asistente_compras.php, includes/shopping_agent.php, includes/shopping_ai.php,
config/shopping_agent.php y config/shopping_agent.ollama4b.example.php.
Conserva tu configuración de base de datos y crea la configuración local como
se explica arriba. HOSTING_Y_CATALOGOS.md sigue aplicando para las fuentes externas.

Validación: nueve archivos PHP analizados con parser, sin errores de sintaxis.
No se dispone aquí de ejecución PHP/MySQL ni del Ollama de tu Mac; faltan la
prueba de conexión y el recorrido completo en tu instalación.
