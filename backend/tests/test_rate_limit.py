import time

from backend.rate_limit import SlidingLimiter


def test_rate_limit_per_minute(monkeypatch):
    current = 0.0

    def fake_time():
        return current

    monkeypatch.setattr(time, "time", fake_time)
    limiter = SlidingLimiter(per_minute=1, per_day=10)

    assert limiter.allow("ip") is True
    assert limiter.allow("ip") is False

    current = 61.0
    assert limiter.allow("ip") is True


def test_rate_limit_per_day(monkeypatch):
    current = 0.0

    def fake_time():
        return current

    monkeypatch.setattr(time, "time", fake_time)
    limiter = SlidingLimiter(per_minute=10, per_day=2)

    assert limiter.allow("ip") is True
    assert limiter.allow("ip") is True
    assert limiter.allow("ip") is False

    current = 86401.0
    assert limiter.allow("ip") is True


def test_rate_limit_reset_boundaries(monkeypatch):
    current = 0.0

    def fake_time():
        return current

    monkeypatch.setattr(time, "time", fake_time)

    limiter = SlidingLimiter(per_minute=1, per_day=10)
    assert limiter.allow("ip") is True

    current = 60.0
    assert limiter.allow("ip") is False

    current = 60.001
    assert limiter.allow("ip") is True

    limiter = SlidingLimiter(per_minute=10, per_day=1)
    current = 0.0
    assert limiter.allow("ip") is True

    current = 86400.0
    assert limiter.allow("ip") is False

    current = 86400.001
    assert limiter.allow("ip") is True
