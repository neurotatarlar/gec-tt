#!/usr/bin/env bash
set -euo pipefail

APP_USER=${APP_USER:-gec-tt-bot}
WG_INTERFACE=${WG_INTERFACE:-wg0}
VPN_TABLE=${VPN_TABLE:-51820}
WG_CONFIG=${WG_CONFIG:-}
INIT_ROOT=${INIT_ROOT:-$(pwd)}
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH

POLICY_SRC=${POLICY_SRC:-$INIT_ROOT/deploy/vpn_policy.sh}
SERVICE_SRC=${SERVICE_SRC:-$INIT_ROOT/deploy/systemd/gec-tt-vpn-policy.service}
ENV_FILE=/etc/default/gec-tt-vpn-policy

if [ -z "$WG_CONFIG" ]; then
  echo "WG_CONFIG is required" >&2
  exit 1
fi

log_step() {
  echo "==> $1"
}

run_step() {
  local label="$1"
  shift
  log_step "$label"
  if command -v timeout >/dev/null 2>&1; then
    if ! timeout 60s "$@"; then
      echo "Step timed out or failed: $label" >&2
      return 1
    fi
  else
    "$@"
  fi
}

SUDO="sudo"
if [ "$(id -u)" -eq 0 ]; then
  SUDO=""
fi

if ! command -v wg-quick >/dev/null 2>&1; then
  echo "wg-quick not found. Install wireguard-tools first." >&2
  exit 1
fi
if ! command -v nft >/dev/null 2>&1; then
  echo "nft not found. Install nftables first." >&2
  exit 1
fi
if ! command -v resolvconf >/dev/null 2>&1; then
  echo "resolvconf not found. Install resolvconf (or openresolv) first." >&2
  exit 1
fi

run_step "Write WireGuard config" $SUDO install -d -m 700 /etc/wireguard
printf '%s\n' "$WG_CONFIG" | tr -d '\r' | $SUDO tee "/etc/wireguard/${WG_INTERFACE}.conf" >/dev/null
run_step "Lock WireGuard config permissions" $SUDO chmod 600 "/etc/wireguard/${WG_INTERFACE}.conf"

if [ ! -f "$POLICY_SRC" ] || [ ! -f "$SERVICE_SRC" ]; then
  echo "VPN policy artifacts not found in $INIT_ROOT" >&2
  exit 1
fi

run_step "Install VPN policy helper" $SUDO install -m 755 "$POLICY_SRC" /usr/local/bin/gec-tt-vpn-policy
run_step "Install VPN policy service" $SUDO install -m 644 "$SERVICE_SRC" /etc/systemd/system/gec-tt-vpn-policy.service

cat <<EOF | $SUDO tee "$ENV_FILE" >/dev/null
APP_USER=$APP_USER
WG_INTERFACE=$WG_INTERFACE
VPN_TABLE=$VPN_TABLE
EOF

endpoint_line=$(printf '%s\n' "$WG_CONFIG" | sed -n 's/^Endpoint *= *//p' | head -n 1)
if [ -n "$endpoint_line" ]; then
  endpoint_host="${endpoint_line%%:*}"
  if ! printf '%s' "$endpoint_host" | grep -Eq '^[0-9.]+$|:'; then
    log_step "Check WireGuard endpoint DNS: $endpoint_host"
    if ! getent ahosts "$endpoint_host" >/dev/null 2>&1; then
      echo "Endpoint hostname does not resolve: $endpoint_host" >&2
      echo "Fix DNS on the VPS or use an IP address in WG_CONFIG." >&2
      exit 1
    fi
  fi
fi

run_step "Reload systemd" $SUDO systemctl daemon-reload
run_step "Load wireguard kernel module" $SUDO modprobe wireguard
if ! run_step "Enable wg-quick@${WG_INTERFACE}" $SUDO systemctl enable --now "wg-quick@${WG_INTERFACE}"; then
  $SUDO systemctl status --no-pager "wg-quick@${WG_INTERFACE}" || true
  $SUDO journalctl -xeu "wg-quick@${WG_INTERFACE}" --no-pager | tail -n 200 || true
  $SUDO systemctl stop "wg-quick@${WG_INTERFACE}" || true
  exit 1
fi
run_step "Enable VPN policy service" $SUDO systemctl enable --now gec-tt-vpn-policy.service
