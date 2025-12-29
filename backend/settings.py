import os
from dataclasses import dataclass


def _get(name: str, default: str) -> str:
    return os.getenv(name, default)


def _get_int(name: str, default: int) -> int:
    try:
        return int(os.getenv(name, default))
    except (TypeError, ValueError):
        return default


@dataclass
class Settings:
    port: int = _get_int("PORT", 3000)
    service_name: str = _get("SERVICE_NAME", "tatar-gec")
    version: str = _get("VERSION", "0.1.0")
    git_sha: str = _get("GIT_SHA", "dev")
    max_chars: int = _get_int("MAX_CHARS", 5000)
    max_body_bytes: int = _get_int("MAX_BODY_BYTES", 200000)
    rate_limit_per_minute: int = _get_int("RATE_LIMIT_PER_MINUTE", 60)
    rate_limit_per_day: int = _get_int("RATE_LIMIT_PER_DAY", 1000)
    max_concurrent_streams: int = _get_int("MAX_CONCURRENT_STREAMS", 3)
    heartbeat_ms: int = _get_int("HEARTBEAT_MS", 20000)
    model_backend: str = _get("MODEL_BACKEND", "mock")
    prompt_version: str = _get("PROMPT_VERSION", "v1")
    cache_ttl_ms: int = _get_int("CACHE_TTL_MS", 60000)


def get_settings() -> Settings:
    return Settings()
