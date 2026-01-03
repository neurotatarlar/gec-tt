#!/usr/bin/env bash
set -euo pipefail

APP_USER=${APP_USER:-gec-tt-bot}
WG_INTERFACE=${WG_INTERFACE:-wg0}
VPN_TABLE=${VPN_TABLE:-51820}
WG_CONFIG=${WG_CONFIG:-}
INIT_ROOT=${INIT_ROOT:-$(pwd)}

POLICY_SRC=${POLICY_SRC:-$INIT_ROOT/deploy/vpn_policy.sh}
SERVICE_SRC=${SERVICE_SRC:-$INIT_ROOT/deploy/systemd/gec-tt-vpn-policy.service}
ENV_FILE=/etc/default/gec-tt-vpn-policy

if [ -z "$WG_CONFIG" ]; then
  echo "WG_CONFIG is required" >&2
  exit 1
fi

SUDO="sudo"
if [ "$(id -u)" -eq 0 ]; then
  SUDO=""
fi

export DEBIAN_FRONTEND=noninteractive
$SUDO apt-get update -y
$SUDO apt-get install -y wireguard wireguard-tools nftables

$SUDO install -d -m 700 /etc/wireguard
printf '%s\n' "$WG_CONFIG" | tr -d '\r' | $SUDO tee "/etc/wireguard/${WG_INTERFACE}.conf" >/dev/null
$SUDO chmod 600 "/etc/wireguard/${WG_INTERFACE}.conf"

if [ ! -f "$POLICY_SRC" ] || [ ! -f "$SERVICE_SRC" ]; then
  echo "VPN policy artifacts not found in $INIT_ROOT" >&2
  exit 1
fi

$SUDO install -m 755 "$POLICY_SRC" /usr/local/bin/gec-tt-vpn-policy
$SUDO install -m 644 "$SERVICE_SRC" /etc/systemd/system/gec-tt-vpn-policy.service

cat <<EOF | $SUDO tee "$ENV_FILE" >/dev/null
APP_USER=$APP_USER
WG_INTERFACE=$WG_INTERFACE
VPN_TABLE=$VPN_TABLE
EOF

$SUDO systemctl daemon-reload
$SUDO modprobe wireguard || true
if ! $SUDO systemctl enable --now "wg-quick@${WG_INTERFACE}"; then
  $SUDO systemctl status --no-pager "wg-quick@${WG_INTERFACE}" || true
  $SUDO journalctl -xeu "wg-quick@${WG_INTERFACE}" --no-pager | tail -n 200 || true
  exit 1
fi
$SUDO systemctl enable --now gec-tt-vpn-policy.service
