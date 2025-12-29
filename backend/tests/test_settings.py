from backend.settings import Settings


def test_settings_invalid_int_falls_back(monkeypatch):
    monkeypatch.setenv("RATE_LIMIT_PER_MINUTE", "nope")
    monkeypatch.setenv("MAX_CONCURRENT_STREAMS", "NaN")
    settings = Settings()

    assert settings.rate_limit_per_minute == 60
    assert settings.max_concurrent_streams == 3
