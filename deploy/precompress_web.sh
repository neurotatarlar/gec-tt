#!/usr/bin/env bash
set -euo pipefail

ROOT=${1:-}
if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then
  echo "Usage: $0 <web-root>" >&2
  exit 1
fi

has_brotli=false
if command -v brotli >/dev/null 2>&1; then
  has_brotli=true
fi

while IFS= read -r -d '' file; do
  case "$file" in
    *.br|*.gz) continue ;;
  esac
  if [ "$has_brotli" = true ]; then
    brotli -f -k -q 11 "$file"
  fi
  gzip -kf -9 "$file"
done < <(
  find "$ROOT" -type f \( \
    -name '*.mjs' -o \
    -name '*.js' -o \
    -name '*.wasm' -o \
    -name '*.css' -o \
    -name '*.json' -o \
    -name '*.svg' -o \
    -name '*.ttf' -o \
    -name '*.otf' -o \
    -name '*.woff' -o \
    -name '*.woff2' \
  \) -print0
)
