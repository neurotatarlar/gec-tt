#!/usr/bin/env bash
set -euo pipefail

APP_USER=${APP_USER:-gec-tt-bot}
APP_DIR=${APP_DIR:-/opt/gec_tt}
WEB_DIR=${WEB_DIR:-/var/www/gec_tt}
NGINX_SITE=${NGINX_SITE:-/etc/nginx/sites-available/gec-annotation.conf}
NGINX_SNIPPET=/etc/nginx/snippets/gec-tt-app.conf
NGINX_BROTLI_SNIPPET=/etc/nginx/snippets/gec-tt-brotli.conf
SERVICE_NAME=gec-tt-backend
SERVICE_PATH=/etc/systemd/system/${SERVICE_NAME}.service
INIT_ROOT=${INIT_ROOT:-/tmp/gec-tt-init}
ENV_SRC=${ENV_SRC:-$INIT_ROOT/.env.example}
SERVICE_SRC=${SERVICE_SRC:-$INIT_ROOT/deploy/systemd/gec-tt-backend.service}
NGINX_SRC=${NGINX_SRC:-$INIT_ROOT/deploy/nginx/gec-tt-app.conf}
NGINX_BROTLI_SRC=${NGINX_BROTLI_SRC:-$INIT_ROOT/deploy/nginx/gec-tt-brotli.conf}

if [ ! -f "$ENV_SRC" ] || [ ! -f "$SERVICE_SRC" ] || [ ! -f "$NGINX_SRC" ]; then
  echo "Missing init assets in $INIT_ROOT" >&2
  exit 1
fi

if [ ! -f "$NGINX_SITE" ]; then
  echo "Nginx site not found: $NGINX_SITE" >&2
  exit 1
fi

if ! id -u "$APP_USER" >/dev/null 2>&1; then
  sudo useradd --create-home --shell /bin/bash "$APP_USER"
fi

sudo mkdir -p "$APP_DIR" "$WEB_DIR"
sudo chown -R "$APP_USER":"$APP_USER" "$APP_DIR" "$WEB_DIR"

if [ ! -d "$APP_DIR/venv" ]; then
  sudo -u "$APP_USER" python3 -m venv "$APP_DIR/venv"
fi

sudo -u "$APP_USER" "$APP_DIR/venv/bin/pip" install --upgrade pip setuptools wheel

if [ ! -f "$APP_DIR/.env" ]; then
  sudo install -m 600 -o "$APP_USER" -g "$APP_USER" "$ENV_SRC" "$APP_DIR/.env"
fi

tmp_service="$(mktemp)"
sed -e "s|__APP_USER__|$APP_USER|g" -e "s|__APP_DIR__|$APP_DIR|g" "$SERVICE_SRC" > "$tmp_service"
sudo install -m 644 "$tmp_service" "$SERVICE_PATH"
rm -f "$tmp_service"

sudo install -m 644 "$NGINX_SRC" "$NGINX_SNIPPET"
if nginx -V 2>&1 | grep -qi brotli; then
  sudo install -m 644 "$NGINX_BROTLI_SRC" "$NGINX_BROTLI_SNIPPET"
else
  sudo install -m 644 /dev/null "$NGINX_BROTLI_SNIPPET"
fi
if ! sudo grep -q "$NGINX_SNIPPET" "$NGINX_SITE"; then
  sudo python3 - <<PY
from pathlib import Path

path = Path("$NGINX_SITE")
text = path.read_text()
snippet = "    include $NGINX_SNIPPET;"
if snippet not in text:
    idx = text.rfind("}")
    if idx == -1:
        raise SystemExit("Nginx site has no closing brace")
    text = f"{text[:idx]}\n{snippet}\n{text[idx:]}"
    path.write_text(text)
PY
fi
sudo python3 - <<'PY'
from pathlib import Path

path = Path("/etc/nginx/mime.types")
text = path.read_text()
needs_mjs = "application/javascript mjs;" not in text
needs_wasm = "application/wasm wasm;" not in text
if needs_mjs or needs_wasm:
    lines = text.splitlines()
    out = []
    inserted = False
    for line in lines:
        out.append(line)
        if not inserted and line.strip().startswith("types"):
            if needs_mjs:
                out.append("    application/javascript mjs;")
            if needs_wasm:
                out.append("    application/wasm wasm;")
            inserted = True
    path.write_text("\n".join(out) + "\n")
PY

sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"

sudo nginx -t
sudo systemctl reload nginx
