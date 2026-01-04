import asyncio
import hashlib
import uuid
from collections.abc import AsyncGenerator

from .settings import Settings


class ModelAdapter:
    name = "base"

    async def correct(self, text: str, lang: str, request_id: str) -> str:
        raise NotImplementedError

    def correct_stream(self, text: str, lang: str, request_id: str) -> AsyncGenerator[str, None]:
        raise NotImplementedError


class MockAdapter(ModelAdapter):
    name = "mock"

    async def correct(self, text: str, lang: str, request_id: str) -> str:  # noqa: ARG002
        return normalize(text)

    async def correct_stream(self, text: str, lang: str, request_id: str):  # noqa: ARG002
        corrected = await self.correct(text, lang, request_id)
        for chunk in chunk_text(corrected, 28):
            await asyncio.sleep(0.12)
            yield chunk


class PromptAdapter(ModelAdapter):
    def __init__(self, prompt_version: str):
        self.prompt_version = prompt_version
        self.name = "prompt"

    async def correct(self, text: str, lang: str, request_id: str) -> str:  # noqa: ARG002
        return f"{normalize(text)} [prompt:{self.prompt_version}]"

    async def correct_stream(self, text: str, lang: str, request_id: str):  # noqa: ARG002
        corrected = await self.correct(text, lang, request_id)
        for chunk in chunk_text(corrected, 28):
            await asyncio.sleep(0.12)
            yield chunk


class LocalAdapter(ModelAdapter):
    name = "local"

    async def correct(self, text: str, lang: str, request_id: str) -> str:  # noqa: ARG002
        return f"{normalize(text)} [local-model]"

    async def correct_stream(self, text: str, lang: str, request_id: str):  # noqa: ARG002
        corrected = await self.correct(text, lang, request_id)
        for chunk in chunk_text(corrected, 32):
            await asyncio.sleep(0.1)
            yield chunk


def build_adapter(settings: Settings) -> ModelAdapter:
    backend = settings.model_backend.strip().lower()
    if backend == "gemini":
        from .gemini import GeminiAdapter

        return GeminiAdapter(settings.gemini_api_keys, settings.gemini_model)
    if backend == "prompt":
        return PromptAdapter(settings.prompt_version)
    if backend == "local":
        return LocalAdapter()
    return MockAdapter()


def normalize(text: str) -> str:
    cleaned = " ".join(text.split()).strip()
    if not cleaned:
        return ""
    return cleaned[0].upper() + cleaned[1:]


def chunk_text(text: str, size: int):
    for i in range(0, len(text), size):
        yield text[i : i + size]


def cache_key(text: str, lang: str) -> str:
    return hashlib.sha256(f"{text}{lang}".encode()).hexdigest()


def request_id() -> str:
    return uuid.uuid4().hex
