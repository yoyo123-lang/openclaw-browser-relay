# Problemas conocidos y guía de debug — OpenClaw Browser Relay

Este repositorio contiene la versión original de la extensión "OpenClaw Browser Relay" extraída de la instalación local de OpenClaw.

Problemas frecuentes detectados

1) Errores de conexión WebSocket / permiso
- Síntomas: al intentar conectar con el gateway local, la extensión muestra errores en consola: "WebSocket connection error" o "Permission denied".
- Causa probable: el gateway local no está escuchando en la URL configurada o la extensión no tiene permisos/host_permissions correctos.
- Debug:
  - Abrir DevTools de la extensión (background service worker) y mirar la pestaña Console.
  - Confirmar URL del gateway en las options (options.html/js).
  - Probar conectar manualmente con curl / websocat a la URL de gateway.

2) evaluate_error / ejecuciones JS fallidas
- Síntomas: código 1003 `evaluate_error`, mensajes con `SyntaxError: Unexpected token '<'` o 'No result returned'.
- Causa probable: la página objetivo bloquea inyección (CSP), el selector no existe, o el código a evaluar contiene errores.
- Debug:
  - Intentar la misma evaluación desde DevTools de la pestaña objetivo.
  - Habilitar modo verbose en la extensión (si existe) o agregar console.log con requestId y código enviado.
  - Revisar headers CSP en la pestaña Network → Response headers → Content-Security-Policy.

3) selector_not_found / elementos inexistentes
- Síntomas: código 1002 `selector_not_found` o funciones que devuelven "Element not found".
- Causa probable: selectors dinámicos, frames, o all_frames flag mal configurado.
- Debug:
  - Reproducir el selector en la consola de la página target: document.querySelectorAll('<selector>').length
  - Si la página usa iframes, comprobar communication entre frames y ajustar all_frames y run_at en manifest.

4) Tab not attached / detached_session
- Síntomas: errores 'Tab not attached' o 'detached_session'.
- Causa probable: la pestaña objetivo fue recargada o cerrada entre request y ejecución.
- Debug:
  - Reproducir flujo: attach → perform action → detach. Asegurarse de mantener la pestaña activa.
  - Añadir logs con timestamps cuando se attach/detach.

Cómo generar logs detallados (rápido)
- Abrir chrome://extensions → activar 'Developer mode' → localizar OpenClaw Browser Relay → Inspect background (service worker) → Console.
- Hacer acciones desde popup o desde el gateway y copiar la salida de la consola.
- Guardar logs en un archivo (copiar/pegar) y crear un issue con evidencia.

Sugerencias de corrección
- Añadir requestId a todos los outputs de console.error y a respuestas de error.
- Mejorar diagnostics para evaluate_error: incluir reason (CSP/frame-blocked/no-content-script/element-not-found) y stack cuando esté disponible.
- Evitar host_permissions globales si no son necesarias; restringir a localhost y dominios requeridos.

Si querés, puedo:
- Crear issues en este repo con las tareas priorizadas y checklists.
- Añadir un script simple para validación de manifest y detección de CSP en una URL de prueba.
- Preparar un PR con cambios mínimos para mejorar logging.
