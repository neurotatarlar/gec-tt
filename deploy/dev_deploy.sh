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
MODEL_BACKEND=${MODEL_BACKEND:-gemini}

HAS_WHEEL=false
HAS_WEB=false
if [ -n "$WHEEL_PATH" ] && [ -f "$WHEEL_PATH" ]; then
  HAS_WHEEL=true
fi
if [ -n "$WEB_ARCHIVE" ] && [ -f "$WEB_ARCHIVE" ]; then
  HAS_WEB=true
fi
if [ "$HAS_WHEEL" = false ] && [ "$HAS_WEB" = false ]; then
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

if [ "$HAS_WHEEL" = true ]; then
  update_env VERSION "$APP_VERSION"
  update_env GIT_SHA "$APP_GIT_SHA"
  update_env MODEL_BACKEND "${MODEL_BACKEND:-}"
  update_env GEMINI_MODEL "${GEMINI_MODEL:-}"
  update_env GEMINI_API_KEYS "${GEMINI_API_KEYS:-}"
fi

if [ "$HAS_WHEEL" = true ]; then
  sudo -u "$APP_USER" "$APP_DIR/venv/bin/pip" install --upgrade --force-reinstall "$WHEEL_PATH"
fi

if [ "$HAS_WEB" = true ]; then
  sudo rm -rf "$WEB_DIR"/*
  sudo tar -xzf "$WEB_ARCHIVE" -C "$WEB_DIR"
  sudo chown -R "$APP_USER":"$APP_USER" "$WEB_DIR"
fi

if [ "$HAS_WHEEL" = true ]; then
  sudo systemctl restart "$SERVICE_NAME"
fi
if [ "$HAS_WEB" = true ]; then
  sudo systemctl reload nginx
fi
