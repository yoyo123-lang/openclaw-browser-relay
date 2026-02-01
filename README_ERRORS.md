# Problemas conocidos y guía de debug — OpenClaw Browser Relay

Este repositorio contiene la versión original de la extensión "OpenClaw Browser Relay" extraída de la instalación local de OpenClaw.

## Problemas frecuentes detectados

### 1. Errores de conexión WebSocket / permiso

**Síntomas:** Al intentar conectar con el gateway local, la extensión muestra errores en consola: `WebSocket connection error` o `Permission denied`.

**Causa probable:** El gateway local no está escuchando en la URL configurada o la extensión no tiene permisos/host_permissions correctos.

**Debug:**
- Abrir DevTools de la extensión (background service worker) y mirar la pestaña Console
- Confirmar URL del gateway en las options (`options.html`/`options.js`)
- Probar conectar manualmente: `curl http://127.0.0.1:18792/` o `websocat ws://127.0.0.1:18792/extension`

### 2. evaluate_error / ejecuciones JS fallidas

**Síntomas:** Código `1003` `evaluate_error`, mensajes con `SyntaxError: Unexpected token '<'` o `No result returned`.

**Causa probable:** La página objetivo bloquea inyección (CSP), el selector no existe, o el código a evaluar contiene errores.

**Debug:**
- Intentar la misma evaluación desde DevTools de la pestaña objetivo
- Habilitar modo verbose en la extensión (si existe) o agregar `console.log` con `requestId` y código enviado
- Revisar headers CSP en la pestaña Network → Response headers → `Content-Security-Policy`

### 3. selector_not_found / elementos inexistentes

**Síntomas:** Código `1002` `selector_not_found` o funciones que devuelven `Element not found`.

**Causa probable:** Selectors dinámicos, frames, o `all_frames` flag mal configurado.

**Debug:**
- Reproducir el selector en la consola de la página target: `document.querySelectorAll('<selector>').length`
- Si la página usa iframes, comprobar communication entre frames y ajustar `all_frames` y `run_at` en manifest

### 4. Tab not attached / detached_session / tab not found

**Síntomas:** Errores `Tab not attached`, `detached_session`, o `tab not found (no attached Chrome tabs for profile "chrome")`.

**Causa probable:**
- La pestaña objetivo fue recargada o cerrada entre request y ejecución
- El Gateway abrió una pestaña directamente (no a través de `Target.createTarget`) y no está adjunta al relay
- Race condition: `browser.open` crea la pestaña pero `browser.navigate` se ejecuta antes de que se complete el attach

**Debug:**
- Reproducir flujo: attach → perform action → detach. Asegurarse de mantener la pestaña activa
- Usar el comando `listAttachedTabs` desde el Gateway para ver qué pestañas están conectadas
- Verificar que el badge de la extensión muestra `ON` en la pestaña objetivo
- Revisar logs del service worker para ver eventos de attach/detach con timestamps

**Solución rápida:**
1. Hacer clic en el icono de OpenClaw Browser Relay en la pestaña que quieres controlar (debe mostrar `ON`)
2. Si el Gateway creó la pestaña directamente, usa `attachTabByUrl` con un patrón de URL para adjuntarla
3. El mensaje de error ahora indica cuántas tabs están adjuntas y sus targetIds para facilitar diagnóstico

## Cómo generar logs detallados

1. Abrir `chrome://extensions`
2. Activar "Developer mode"
3. Localizar **OpenClaw Browser Relay**
4. Click en "Inspect views: service worker" → Console
5. Hacer acciones desde popup o desde el gateway y copiar la salida de la consola
6. Guardar logs en un archivo (copiar/pegar) y crear un issue con evidencia

## Códigos de error

| Código | Nombre | Descripción |
|--------|--------|-------------|
| 1002 | `selector_not_found` | El selector CSS no encontró elementos |
| 1003 | `evaluate_error` | Error al ejecutar JavaScript en la página |
| - | `detached_session` | La sesión de debug fue desconectada |
| - | `tab not found` | No hay pestañas adjuntas al relay |

## Comandos de diagnóstico

La extensión soporta comandos especiales para diagnóstico (enviar via WebSocket al relay):

### listAttachedTabs

Lista todas las pestañas actualmente adjuntas.

```json
{ "id": 1, "method": "listAttachedTabs" }
```

Respuesta:
```json
{
  "id": 1,
  "result": {
    "tabs": [
      {
        "tabId": 123,
        "sessionId": "cb-tab-1",
        "targetId": "14DC27CEEBBA6C8B2233046A34F29C49",
        "url": "https://google.com",
        "title": "Google"
      }
    ]
  }
}
```

### attachTabByUrl

Adjunta una pestaña existente por patrón de URL.

```json
{ "id": 2, "method": "attachTabByUrl", "params": { "urlPattern": "google.com" } }
```

Útil cuando el Gateway abre pestañas directamente y necesitas adjuntarlas al relay.

## Sugerencias de mejora (implementadas)

- ✅ `requestId` incluido en todos los logs de error
- ✅ Timestamps ISO 8601 en logs estructurados
- ✅ Mensaje de error mejorado con info de tabs adjuntas
- ✅ Auto-reattach cuando una pestaña se recarga
- ✅ Comandos de diagnóstico (`listAttachedTabs`, `attachTabByUrl`)
