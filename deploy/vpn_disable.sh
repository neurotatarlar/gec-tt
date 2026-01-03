#!/usr/bin/env bash
set -euo pipefail

WG_INTERFACE=${WG_INTERFACE:-wg0}

SUDO="sudo"
if [ "$(id -u)" -eq 0 ]; then
  SUDO=""
fi

$SUDO systemctl disable --now gec-tt-vpn-policy.service 2>/dev/null || true
$SUDO systemctl disable --now "wg-quick@${WG_INTERFACE}" 2>/dev/null || true

if [ -x /usr/local/bin/gec-tt-vpn-policy ]; then
  $SUDO /usr/local/bin/gec-tt-vpn-policy disable || true
fi
