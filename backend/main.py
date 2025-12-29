import asyncio
import json
import time
from collections.abc import AsyncGenerator
from typing import Any

from dotenv import load_dotenv
from fastapi import Depends, FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response, StreamingResponse

from .cache import SimpleCache
from .metrics import (
    CACHE_HITS,
    METRICS_CONTENT_TYPE,
    REQUEST_LATENCY,
    REQUESTS_TOTAL,
    STREAM_DURATION,
    STREAMS_ACTIVE,
    STREAMS_TOTAL,
    render_metrics,
)
from .models import ModelAdapter, build_adapter, cache_key, request_id
from .rate_limit import SlidingLimiter
from .settings import Settings, get_settings

app = FastAPI(title="Tatar GEC")
load_dotenv()


class AppState:
    def __init__(self, settings: Settings):
        self.settings = settings
        self.adapter: ModelAdapter = build_adapter(settings)
        self.cache = SimpleCache(settings.cache_ttl_ms)
        self.rates = SlidingLimiter(settings.rate_limit_per_minute, settings.rate_limit_per_day)
        self.streams: dict[str, int] = {}
        self.started_at = time.time()
        self.total_requests = 0
        self.total_invalid = 0
        self.total_rate_limited = 0
        self.total_errors = 0
        self.total_cache_hits = 0
        self.total_streams_started = 0
        self.total_streams_done = 0
        self.total_streams_cancelled = 0
        self.total_streams_error = 0


async def get_state() -> AppState:
    if not hasattr(app.state, "app_state"):
        app.state.app_state = AppState(get_settings())
    return app.state.app_state


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.get("/version")
async def version(state: AppState = Depends(get_state)):
    return {
        "service": state.settings.service_name,
        "version": state.settings.version,
        "git": state.settings.git_sha,
    }


@app.get("/status")
async def status(state: AppState = Depends(get_state)):
    uptime = int(time.time() - state.started_at)
    return {
        "status": "ok",
        "uptime_seconds": uptime,
        "active_streams": sum(state.streams.values()),
        "requests_total": state.total_requests,
        "invalid_requests_total": state.total_invalid,
        "rate_limited_total": state.total_rate_limited,
        "errors_total": state.total_errors,
        "cache_hits_total": state.total_cache_hits,
        "streams": {
            "started": state.total_streams_started,
            "done": state.total_streams_done,
            "cancelled": state.total_streams_cancelled,
            "error": state.total_streams_error,
        },
        "limits": {
            "max_concurrent_streams": state.settings.max_concurrent_streams,
            "rate_limit_per_minute": state.settings.rate_limit_per_minute,
            "rate_limit_per_day": state.settings.rate_limit_per_day,
        },
    }


@app.get("/metrics")
async def metrics():
    return Response(render_metrics(), media_type=METRICS_CONTENT_TYPE)


@app.post("/v1/correct")
async def correct(request: Request, state: AppState = Depends(get_state)):
    state.total_requests += 1
    started = time.time()
    try:
        ensure_json_request(request)
        await enforce_body_size(request, state.settings.max_body_bytes)
        body = await parse_json_body(request)
        text = str(body.get("text", ""))
        lang = body.get("lang") or "tt"
        validate_text(text, state.settings.max_chars)
    except HTTPException:
        state.total_invalid += 1
        REQUESTS_TOTAL.labels(endpoint="correct", outcome="invalid_input").inc()
        REQUEST_LATENCY.labels(endpoint="correct").observe(time.time() - started)
        raise
    ip = client_ip(request)
    if not state.rates.allow(ip):
        state.total_rate_limited += 1
        REQUESTS_TOTAL.labels(endpoint="correct", outcome="rate_limited").inc()
        REQUEST_LATENCY.labels(endpoint="correct").observe(time.time() - started)
        raise HTTPException(status_code=429, detail={"error": "rate_limited"})

    rid = request_id()
    cached = state.cache.get(cache_key(text, lang))
    if cached:
        state.total_cache_hits += 1
        CACHE_HITS.inc()
        REQUESTS_TOTAL.labels(endpoint="correct", outcome="cache").inc()
        REQUEST_LATENCY.labels(endpoint="correct").observe(time.time() - started)
        return {
            "request_id": rid,
            "corrected_text": cached.value,
            "meta": {"model_backend": cached.backend, "latency_ms": 0},
        }

    try:
        corrected = await state.adapter.correct(text, lang, rid)
    except Exception as err:  # noqa: BLE001
        state.total_errors += 1
        REQUESTS_TOTAL.labels(endpoint="correct", outcome="error").inc()
        REQUEST_LATENCY.labels(endpoint="correct").observe(time.time() - started)
        raise HTTPException(
            status_code=500, detail={"error": "server_error", "request_id": rid}
        ) from err

    state.cache.set(cache_key(text, lang), corrected, state.adapter.name)
    latency = int((time.time() - started) * 1000)
    REQUESTS_TOTAL.labels(endpoint="correct", outcome="ok").inc()
    REQUEST_LATENCY.labels(endpoint="correct").observe(time.time() - started)
    return {
        "request_id": rid,
        "corrected_text": corrected,
        "meta": {"model_backend": state.adapter.name, "latency_ms": latency},
    }


@app.post("/v1/correct/stream")
async def correct_stream(request: Request, state: AppState = Depends(get_state)):
    state.total_requests += 1
    try:
        ensure_json_request(request)
        await enforce_body_size(request, state.settings.max_body_bytes)
        body = await parse_json_body(request)
        text = str(body.get("text", ""))
        lang = body.get("lang") or "tt"
        validate_text(text, state.settings.max_chars)
    except HTTPException:
        state.total_invalid += 1
        REQUESTS_TOTAL.labels(endpoint="stream", outcome="invalid_input").inc()
        raise
    ip = client_ip(request)
    if not state.rates.allow(ip):
        state.total_rate_limited += 1
        REQUESTS_TOTAL.labels(endpoint="stream", outcome="rate_limited").inc()
        raise HTTPException(status_code=429, detail={"error": "rate_limited"})

    # concurrency guard
    count = state.streams.get(ip, 0)
    if count >= state.settings.max_concurrent_streams:
        state.total_rate_limited += 1
        REQUESTS_TOTAL.labels(endpoint="stream", outcome="rate_limited").inc()
        raise HTTPException(
            status_code=429, detail={"error": "rate_limited", "message": "too_many_streams"}
        )
    state.streams[ip] = count + 1

    rid = request_id()
    started = time.time()
    state.total_streams_started += 1
    STREAMS_ACTIVE.inc()
    outcome_recorded = False

    def record_stream_outcome(outcome: str):
        nonlocal outcome_recorded
        if outcome_recorded:
            return
        outcome_recorded = True
        REQUESTS_TOTAL.labels(endpoint="stream", outcome=outcome).inc()
        STREAMS_TOTAL.labels(outcome=outcome).inc()
        STREAM_DURATION.observe(time.time() - started)

    async def event_stream() -> AsyncGenerator[str, None]:
        interval = state.settings.heartbeat_ms / 1000
        corrected = ""
        stream_iter = state.adapter.correct_stream(text, lang, rid)
        try:
            yield sse_event("meta", {"request_id": rid, "model_backend": state.adapter.name})
            while True:
                try:
                    delta = await asyncio.wait_for(stream_iter.__anext__(), timeout=interval)
                    corrected += delta
                    yield sse_event("delta", {"request_id": rid, "text": delta})
                except TimeoutError:
                    yield ": ping\n\n"
                except StopAsyncIteration:
                    latency = int((time.time() - started) * 1000)
                    yield sse_event("done", {"request_id": rid, "latency_ms": latency})
                    if corrected:
                        state.cache.set(cache_key(text, lang), corrected, state.adapter.name)
                    state.total_streams_done += 1
                    record_stream_outcome("ok")
                    break
        except asyncio.CancelledError:
            yield sse_event(
                "error", {"request_id": rid, "type": "cancelled", "message": "client_disconnected"}
            )
            state.total_streams_cancelled += 1
            record_stream_outcome("cancelled")
        except Exception as err:  # noqa: BLE001
            yield sse_event(
                "error", {"request_id": rid, "type": "server_error", "message": str(err)}
            )
            state.total_streams_error += 1
            state.total_errors += 1
            record_stream_outcome("error")
        finally:
            state.streams[ip] = max(0, state.streams.get(ip, 1) - 1)
            STREAMS_ACTIVE.dec()

    headers = {
        "Cache-Control": "no-cache",
        "X-Accel-Buffering": "no",
        "Connection": "keep-alive",
    }
    return StreamingResponse(event_stream(), media_type="text/event-stream", headers=headers)


def sse_event(event: str, data: dict[str, Any]) -> str:
    import json

    return f"event: {event}\ndata: {json.dumps(data, ensure_ascii=False)}\n\n"


def validate_text(text: str, max_chars: int):
    if not text or not text.strip():
        raise HTTPException(status_code=400, detail={"error": "invalid_input", "message": "empty"})
    if len(text) > max_chars:
        raise HTTPException(
            status_code=400, detail={"error": "invalid_input", "message": "too_long"}
        )


def ensure_json_request(request: Request) -> None:
    content_type = request.headers.get("content-type", "")
    media_type = content_type.split(";", 1)[0].strip().lower()
    if media_type != "application/json":
        raise HTTPException(status_code=415, detail={"error": "unsupported_media_type"})


async def enforce_body_size(request: Request, max_bytes: int) -> None:
    length = request.headers.get("content-length")
    if length:
        try:
            if int(length) > max_bytes:
                raise HTTPException(status_code=413, detail={"error": "payload_too_large"})
        except ValueError:
            pass
    body = await request.body()
    if len(body) > max_bytes:
        raise HTTPException(status_code=413, detail={"error": "payload_too_large"})


async def parse_json_body(request: Request) -> dict[str, Any]:
    try:
        payload = await request.json()
    except json.JSONDecodeError as err:
        raise HTTPException(
            status_code=400,
            detail={"error": "invalid_input", "message": "invalid_json"},
        ) from err
    if not isinstance(payload, dict):
        raise HTTPException(
            status_code=400,
            detail={"error": "invalid_input", "message": "invalid_body"},
        )
    return payload


def client_ip(request: Request) -> str:
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)
