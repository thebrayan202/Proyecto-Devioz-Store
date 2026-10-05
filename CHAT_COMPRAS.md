# Asistente de compras en chat

Sube estos tres archivos conservando sus carpetas:
- asistente_compras.php
- assets/css/shopping_chat.css
- assets/js/shopping_chat.js

Abre asistente_compras.php en tu hosting. No requiere migración adicional para la interfaz de chat. Conserva tu configuración y base de datos existentes.

Ejemplos: «Tengo 20 soles para comprar», «Quiero galletas», «Ahora tengo 10 soles».
El chat conserva hasta 30 mensajes en la pestaña y envía hasta 500 caracteres del contexto reciente al selector de productos existente. Nueva conversación borra el historial y preferencias conversacionales; conserva los ajustes del formulario.

El presupuesto escrito actualiza el formulario. Las preferencias de productos y exclusiones dependen de la conexión de IA existente (Ollama u OpenAI); cuando no está disponible, se indica modo básico y se usan categoría, precio y presupuesto de los ajustes. No es un chat de propósito general: responde mediante propuestas del catálogo de alimentos y bebidas sin alcohol. No calcula ahorros externos sin una referencia comparable.

La propuesta puede reemplazar Mi lista con confirmación. No confirma pedidos ni pagos. Las propuestas históricas pueden contener precios o stock anteriores; envía otro mensaje para actualizarlas.

Verificación: sintaxis JavaScript comprobada con Node. El entorno de edición no tiene PHP/MySQL ni navegador Chromium, por lo que queda pendiente la prueba integral en el hosting y la conexión real con Ollama.

## Diseño de la pestaña Asistencia
La pantalla usa un panel amplio inspirado en la referencia: selector Buscar/Devioz IA, bienvenida central, sugerencias horizontales, entrada inferior y diseño adaptable a celular. La pestaña Asistencia queda marcada como activa en el encabezado.
