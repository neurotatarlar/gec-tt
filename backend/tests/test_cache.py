import time

from backend.cache import SimpleCache


def test_cache_expires():
    cache = SimpleCache(ttl_ms=1)
    cache.set("key", "value", "mock")
    entry = cache.get("key")
    assert entry is not None
    assert entry.value == "value"
    time.sleep(0.01)
    assert cache.get("key") is None
