#!/usr/bin/env bash
set -euo pipefail

APP_USER=${APP_USER:-gec-tt-bot}
APP_DIR=${APP_DIR:-/opt/gec_tt}
WEB_DIR=${WEB_DIR:-/var/www/gec_tt}
WHEEL_PATH=${WHEEL_PATH:-/tmp/gec-tt-backend.whl}
WEB_ARCHIVE=${WEB_ARCHIVE:-/tmp/gec-tt-web.tar.gz}
SERVICE_NAME=${SERVICE_NAME:-gec-tt-backend}
APP_VERSION=${APP_VERSION:-}
APP_GIT_SHA=${APP_GIT_SHA:-}

if [ ! -f "$WHEEL_PATH" ] || [ ! -f "$WEB_ARCHIVE" ]; then
  echo "Missing deploy assets." >&2
  exit 1
fi

update_env() {
  local key="$1"
  local value="$2"
  local file="$APP_DIR/.env"
  if [ -z "$value" ]; then
    return
  fi
  if sudo grep -q "^${key}=" "$file"; then
    sudo sed -i "s|^${key}=.*|${key}=${value}|" "$file"
  else
    echo "${key}=${value}" | sudo tee -a "$file" >/dev/null
  fi
}

update_env VERSION "$APP_VERSION"
update_env GIT_SHA "$APP_GIT_SHA"
update_env MODEL_BACKEND "${MODEL_BACKEND:-}"
update_env GEMINI_MODEL "${GEMINI_MODEL:-}"
update_env GEMINI_API_KEYS "${GEMINI_API_KEYS:-}"

sudo -u "$APP_USER" "$APP_DIR/venv/bin/pip" install --upgrade "$WHEEL_PATH"

sudo rm -rf "$WEB_DIR"/*
sudo tar -xzf "$WEB_ARCHIVE" -C "$WEB_DIR"
sudo chown -R "$APP_USER":"$APP_USER" "$WEB_DIR"

sudo systemctl restart "$SERVICE_NAME"
sudo systemctl reload nginx
