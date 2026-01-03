# Deployment (dev VPS)

This repo ships GitHub Actions workflows for a lightweight, non-Docker deployment to a VPS.
The dev instance is served under `/app` and the backend is available at `/app/api`.

## Paths and services
- Backend venv: `/opt/gec_tt/venv`
- Backend config: `/opt/gec_tt/.env`
- Web root: `/var/www/gec_tt`
- Systemd service: `gec-tt-backend`
- Nginx site file: `/etc/nginx/sites-available/gec-annotation.conf`

## GitHub Actions workflows
- `Dev Init` (manual only): initial VPS setup (idempotent).
- `Dev Deploy` (push to `master`): build wheel + web bundle, deploy via SSH.
- `Release Builds` (push to `release/v*`): build artifacts and publish a GitHub Release.

## VPS preparation (first run)
1) Install packages:
```
sudo apt-get update
sudo apt-get install -y python3 python3-venv python3-pip nginx
```
2) Create the deploy user and add its SSH key:
```
sudo useradd --create-home --shell /bin/bash gec-tt-bot
sudo mkdir -p /home/gec-tt-bot/.ssh
sudo tee /home/gec-tt-bot/.ssh/authorized_keys < /path/to/gec_tt_bot.pub
sudo chown -R gec-tt-bot:gec-tt-bot /home/gec-tt-bot/.ssh
sudo chmod 700 /home/gec-tt-bot/.ssh
sudo chmod 600 /home/gec-tt-bot/.ssh/authorized_keys
```
3) Allow `gec-tt-bot` to run these commands via sudo without a password:
   - `systemctl restart gec-tt-backend`
   - `systemctl reload nginx`
   - `nginx -t`
   - `systemctl enable wg-quick@wg0`
   - `systemctl disable wg-quick@wg0`
   - `systemctl start wg-quick@wg0`
   - `systemctl stop wg-quick@wg0`
   - `systemctl enable gec-tt-vpn-policy`
   - `systemctl disable gec-tt-vpn-policy`
   - `systemctl start gec-tt-vpn-policy`
   - `systemctl stop gec-tt-vpn-policy`
   - `systemctl daemon-reload`
   - `apt-get update`
   - `apt-get install`
   - `install`
   - `tee`
   - `ip`
   - `nft`

Example sudoers entry (edit with `visudo`):
```
gec-tt-bot ALL=NOPASSWD:/bin/systemctl restart gec-tt-backend,/bin/systemctl reload nginx,/usr/sbin/nginx -t,/bin/systemctl daemon-reload,/bin/systemctl enable gec-tt-backend,/bin/systemctl enable wg-quick@wg0,/bin/systemctl disable wg-quick@wg0,/bin/systemctl start wg-quick@wg0,/bin/systemctl stop wg-quick@wg0,/bin/systemctl enable gec-tt-vpn-policy,/bin/systemctl disable gec-tt-vpn-policy,/bin/systemctl start gec-tt-vpn-policy,/bin/systemctl stop gec-tt-vpn-policy,/usr/bin/apt-get update,/usr/bin/apt-get install,/usr/bin/install,/usr/bin/tee,/usr/sbin/ip,/usr/sbin/nft
```

## GitHub Secrets
Set these in repo settings:
- `DEV_HOST`: VPS IP
- `DEV_USER`: `gec-tt-bot`
- `DEV_SSH_KEY`: private key contents
- `DEV_SSH_PORT`: `22` (or your custom port)
- `GEMINI_API_KEYS`: comma-separated Gemini API keys (for demo proxy)
- `WG_CONFIG`: WireGuard config content for the VPS (multi-line)

## Nginx routing
The init workflow injects a snippet into the existing nginx site file to serve:
- `/app/` -> `/var/www/gec_tt`
- `/app/api/` -> `127.0.0.1:3000`

If you update nginx manually, use the snippet in `deploy/nginx/gec-tt-app.conf`.
