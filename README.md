# Tatar GEC Service

Streaming grammar/spell correction prototype for Tatar (Cyrillic). Single-page UI with SSE-powered responses and a Python FastAPI backend with pluggable model adapters.

## Prerequisites
- Python 3.11+
- Docker + Docker Compose (for prod-like runs)

## Quickstart (dev)
1. `cp .env.example .env`
2. `python3 -m venv .venv && source .venv/bin/activate`
3. `make install`
4. `make dev`
5. Open http://localhost:3000

## Deployment (dev VPS)
See `deploy/README.md` for the GitHub Actions setup (manual init + auto deploy on `master`).

## Project structure
- `backend/` — FastAPI service (SSE streaming + rate limiting + metrics)
  - `backend/main.py` — API routes (`/health`, `/status`, `/metrics`, `/v1/correct`, `/v1/correct/stream`)
  - `backend/models.py` — model adapter interface + mock/prompt/local adapters
  - `backend/settings.py` — env-driven config (`MAX_CHARS`, limits, backend selection)
  - `backend/rate_limit.py` — in-memory per-IP rate limiter
  - `backend/cache.py` — small TTL cache to avoid duplicate calls
  - `backend/metrics.py` — Prometheus counters/gauges/histograms
- `client/` — Flutter app (web + desktop + mobile)
  - `client/lib/main.dart` — UI layout, panels, settings/history/report sheets
  - `client/lib/app_state.dart` — single source of truth (streaming, layout, settings, history)
  - `client/lib/backend_client.dart` — SSE client for `/v1/correct/stream`
  - `client/lib/models.dart` — data models + enums
  - `client/lib/i18n.dart` — translation loader
  - `client/lib/app_config.dart` — loads `assets/config.json`
  - `client/lib/history_store.dart` — Hive-backed history
  - `client/lib/settings_store.dart` — shared_preferences settings
  - `client/assets/config.json` — backend URL + app name + report links
  - `client/assets/i18n/*.json` — UI translations
  - `client/android/`, `client/ios/`, `client/macos/`, `client/windows/`, `client/linux/`, `client/web/` — Flutter platform scaffolding
- Repo tooling/config
  - `.env.example` — backend defaults (copy to `.env`)
  - `requirements.txt`, `requirements-dev.txt` — backend deps
  - `pyproject.toml` — lint/type config for Python tools
  - `Makefile` — dev/lint/security helpers
  - `Dockerfile`, `docker-compose.yml`, `Caddyfile` — container/proxy setup
  - `.githooks/` — pre-commit hook

## Scripts
- `make dev` — run FastAPI via uvicorn (auto-reload)
- `make test` — run backend tests (pytest)
- `make lint` — lint backend + client
- `make security` — backend security checks (bandit + pip-audit)
- `make check` — lint + security
- `make hooks` — install git hooks from `.githooks`
- `make docker-up` / `make docker-down` — run Compose stack (app + Caddy)
- `make sse-test` — curl SSE stream sample

## API
- `GET /health` → `{ status: "ok" }`
- `GET /version` → `{ service, version, git }`
- `GET /status` → summary counters (uptime, requests, streams, limits)
- `GET /metrics` → Prometheus metrics
- `POST /v1/correct` → `{ request_id, corrected_text, meta }`
- `POST /v1/correct/stream` (SSE) emits `meta`, `delta`, `done`, `error` events. Headers include `Content-Type: text/event-stream`, `Cache-Control: no-cache`, `X-Accel-Buffering: no`; heartbeat comments every 20s.

Payload shape:
```json
{ "text": "...", "lang": "tt", "client": { "platform": "web|mobile", "version": "..." } }
```

Validation: rejects empty/whitespace-only text; enforces `MAX_CHARS`. Rate limits per minute/day plus max concurrent streams per IP.

## Client highlights (Flutter)
- Responsive layout (desktop horizontal split, mobile vertical stack; manual layout toggles).
- i18n via `client/assets/i18n/*.json`; language choice saved locally.
- Streaming UX with incremental output and auto-scroll during generation.
- Local history sheet (desktop dialog, mobile bottom sheet) with clear/save toggles.
- Settings sheet: theme, font size, auto-scroll, history save/clear.
- Report modal with prefilled mailto/Telegram including `request_id`.

## Flutter app (mobile/web/desktop)
- Location: `client`
- Config: `client/assets/config.json` (edit `baseUrl`, `appName`, report links).
- Run (web): `cd client && flutter pub get && flutter run -d chrome`
- Run (desktop/mobile): choose device in `flutter run` and update `baseUrl` to your backend host.
- App identifiers in config are placeholders; native bundle IDs still live in platform folders.

## Configuration
See `.env.example` for tunables (ports, limits, backend adapter, heartbeat). `MODEL_BACKEND` supports `mock`, `prompt`, `local` adapters; swap without UI changes.

## Dev tools
- Backend lint/type/security: `requirements-dev.txt` (install via `make install-dev`).
- Client lint: `very_good_analysis` (run `flutter pub get` in `client/`).
- Pre-commit: run `make hooks` once, then `git commit` runs `make lint`. Set `RUN_SECURITY_CHECKS=1` to include security checks.
- You can override Flutter/Dart binaries with `FLUTTER=/path/to/flutter DART=/path/to/dart make lint-client`.

## Deployment
- Build image: `docker build -t gec-tt .`
- Compose (prod-ish): `docker compose up -d`
- Caddy reverse proxy included with buffering disabled for SSE; enable HTTPS/ACME by editing `Caddyfile` when deploying to a domain.

## SSE troubleshooting
- Ensure reverse proxy disables buffering and respects long-lived connections.
- Heartbeats (`: ping`) every `HEARTBEAT_MS` help keep connections alive.
- Client cancel triggers abort + cleanup of stream counters.

## Capacity tips (SSE)
- Concurrency rule of thumb: `concurrency ≈ RPS × avg_latency_seconds`.
- For 10 RPS with 60s streams, expect ~600 concurrent connections.
- Set `MAX_CONCURRENT_STREAMS` and `RATE_LIMIT_PER_MINUTE` accordingly (>=600/min).
- Run multiple workers for long-lived streams (e.g., 2–4).
- Raise file descriptor limits (`ulimit -n`) to cover peak open streams.
- If proxying through Nginx, disable buffering and set long `proxy_read_timeout`.
- Consider `uvloop` on Linux for lower overhead.

## Metrics (Prometheus UI)
- `/metrics` exposes Prometheus-format metrics.
- If you want a lightweight dashboard without Grafana, run Prometheus and use its built-in web UI.

## Notes
- Logging avoids full text; request metadata only.
- Local cache prevents repeat identical correction calls for a short TTL.
