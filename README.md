# OpenClaw Chrome Extension (Browser Relay)

Purpose: attach OpenClaw to an existing Chrome tab so the Gateway can automate it (via the local CDP relay server).

## Requirements

- Chrome/Chromium browser (v88+)
- OpenClaw Gateway running with browser control enabled
- Relay server listening on `http://127.0.0.1:18792/` (default port)

## Dev / load unpacked

1. Build/run OpenClaw Gateway with browser control enabled.
2. Ensure the relay server is reachable at `http://127.0.0.1:18792/` (default).
3. Install the extension to a stable path:

   ```bash
   openclaw browser extension install
   openclaw browser extension path
   ```

4. Chrome → `chrome://extensions` → enable "Developer mode".
5. "Load unpacked" → select the path printed above.
6. Pin the extension. Click the icon on a tab to attach/detach.

## Options

- `Relay port`: defaults to `18792`.

## Badge indicators

| Badge | Meaning |
|-------|---------|
| `ON` (orange) | Tab attached and connected |
| `…` (yellow) | Connecting to relay server |
| `!` (red) | Error - relay not reachable |
| (empty) | Tab not attached |

## Troubleshooting

### Relay not reachable
1. Verify OpenClaw Gateway is running: `curl http://127.0.0.1:18792/`
2. Check that the port in extension options matches your Gateway config
3. Ensure no firewall is blocking localhost connections

### WebSocket connection failed
1. Open `chrome://extensions` → find OpenClaw Browser Relay → click "Inspect views: service worker"
2. Check Console tab for error messages
3. Verify the relay server supports WebSocket at `/extension` endpoint

### Tab won't attach
1. Some special pages (`chrome://`, `chrome-extension://`, etc.) cannot be debugged
2. Try reloading the target tab first
3. Check if another debugger is already attached to the tab

See [README_ERRORS.md](README_ERRORS.md) for detailed error codes and debugging guide.
