#!/usr/bin/env bash
# repair-relay.sh
# Simple tester + fixer for OpenClaw Browser Relay connectivity
# Usage: ./repair-relay.sh --gateway http://127.0.0.1:9229 --manifest ./manifest.json

set -euo pipefail
GATEWAY="http://127.0.0.1:9229"
MANIFEST="./manifest.json"
TIMEOUT=3

while [[ $# -gt 0 ]]; do
  case $1 in
    --gateway) GATEWAY="$2"; shift 2;;
    --manifest) MANIFEST="$2"; shift 2;;
    --timeout) TIMEOUT="$2"; shift 2;;
    -h|--help) echo "Usage: $0 [--gateway URL] [--manifest PATH]"; exit 0;;
    *) echo "Unknown arg: $1"; exit 1;;
  esac
done

echo "[1/6] Check manifest: $MANIFEST"
if [[ -f "$MANIFEST" ]]; then
  if command -v jq >/dev/null 2>&1; then
    jq . "$MANIFEST" | sed -n '1,40p'
  else
    head -n 40 "$MANIFEST"
  fi
else
  echo "  manifest not found: $MANIFEST"
fi

echo "\n[2/6] Check gateway reachability: $GATEWAY"
if command -v curl >/dev/null 2>&1; then
  if curl -s --max-time $TIMEOUT -I "$GATEWAY" >/dev/null; then
    echo "  Gateway reachable (HTTP HEAD ok)"
  else
    echo "  Gateway NOT reachable via HTTP HEAD"
  fi
else
  echo "  curl not found — skipping HTTP check"
fi

# check listener on host:port
proto_host_port=$(echo "$GATEWAY" | sed -E 's@https?://@@' )
host=$(echo "$proto_host_port" | cut -d':' -f1)
port=$(echo "$proto_host_port" | cut -s -d':' -f2 || echo "")
if [[ -n "$port" ]]; then
  echo "\n[3/6] Check local listener on $host:$port"
  if command -v lsof >/dev/null 2>&1; then
    if lsof -iTCP:"$port" -sTCP:LISTEN -Pn >/dev/null 2>&1; then
      echo "  Process listening on port $port"
      lsof -iTCP:"$port" -sTCP:LISTEN -Pn | sed -n '1,20p'
    else
      echo "  No process listening on port $port"
    fi
  else
    echo "  lsof not installed — try: sudo lsof -iTCP:$port -sTCP:LISTEN -Pn"
  fi
fi

# Check openclaw gateway status and try restart if not running
if command -v openclaw >/dev/null 2>&1; then
  echo "\n[4/6] openclaw gateway status"
  if openclaw gateway status >/dev/null 2>&1; then
    openclaw gateway status || true
    echo "  openclaw gateway reported (see above)"
  else
    echo "  openclaw gateway not running or status failed — attempting to start"
    openclaw gateway start || echo "  failed to start with openclaw gateway start"
    sleep 2
    openclaw gateway status || true
  fi
else
  echo "\n[4/6] openclaw CLI not available in PATH — cannot check gateway service"
fi

# If gateway still unreachable, try to tail logs (common locations)
echo "\n[5/6] Try to gather gateway logs (best effort)"
if [[ -d "/var/log" ]]; then
  # try common log names
  for f in /var/log/openclaw.log /var/log/openclaw/*.log /usr/local/var/log/openclaw.log; do
    if [[ -f "$f" ]]; then
      echo "  Found log: $f (tail -n 40)"
      tail -n 40 "$f" || true
      break
    fi
  done
fi

# Run validator script if present
if [[ -x "./scripts/validate-relay.js" || -f "./scripts/validate-relay.js" ]]; then
  echo "\n[6/6] Run node validator (validate-relay.js)"
  if command -v node >/dev/null 2>&1; then
    # ensure dependencies
    if [[ -f package.json ]]; then
      npm install --no-audit --no-fund >/dev/null 2>&1 || true
    fi
    node ./scripts/validate-relay.js --manifest "$MANIFEST" --gateway "$GATEWAY" || true
    echo "  Validator written diagnostics-relay-output.json"
  else
    echo "  node not available — cannot run validator"
  fi
else
  echo "  No validator script found at ./scripts/validate-relay.js"
fi

echo "\nDone. Review the output above and diagnostics-relay-output.json (if created)."
