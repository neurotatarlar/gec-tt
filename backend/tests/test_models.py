import pytest

from backend.models import MockAdapter, PromptAdapter, normalize


@pytest.mark.asyncio
async def test_mock_adapter_stream_roundtrip():
    adapter = MockAdapter()
    text = "hello   world"
    corrected = await adapter.correct(text, "tt", "rid")

    chunks = []
    async for chunk in adapter.correct_stream(text, "tt", "rid"):
        chunks.append(chunk)

    assert "".join(chunks) == corrected


@pytest.mark.asyncio
async def test_prompt_adapter_includes_version():
    adapter = PromptAdapter("v1")
    corrected = await adapter.correct("text", "tt", "rid")
    assert "prompt:v1" in corrected


def test_normalize():
    assert normalize("  hello   world ") == "Hello world"
