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

Example sudoers entry (edit with `visudo`):
```
gec-tt-bot ALL=NOPASSWD:/bin/systemctl restart gec-tt-backend,/bin/systemctl reload nginx,/usr/sbin/nginx -t,/bin/systemctl daemon-reload,/bin/systemctl enable gec-tt-backend
```

## GitHub Secrets
Set these in repo settings:
- `DEV_HOST`: VPS IP
- `DEV_USER`: `gec-tt-bot`
- `DEV_SSH_KEY`: private key contents
- `DEV_SSH_PORT`: `22` (or your custom port)

## Nginx routing
The init workflow injects a snippet into the existing nginx site file to serve:
- `/app/` -> `/var/www/gec_tt`
- `/app/api/` -> `127.0.0.1:3000`

If you update nginx manually, use the snippet in `deploy/nginx/gec-tt-app.conf`.
