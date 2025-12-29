import time


class CacheEntry:
    def __init__(self, value, backend: str, expires_at: float):
        self.value = value
        self.backend = backend
        self.expires_at = expires_at


class SimpleCache:
    def __init__(self, ttl_ms: int):
        self.store: dict[str, CacheEntry] = {}
        self.ttl_ms = ttl_ms

    def get(self, key: str) -> CacheEntry | None:
        entry = self.store.get(key)
        if not entry:
            return None
        if time.time() * 1000 > entry.expires_at:
            self.store.pop(key, None)
            return None
        return entry

    def set(self, key: str, value, backend: str):
        self.store[key] = CacheEntry(value, backend, time.time() * 1000 + self.ttl_ms)
