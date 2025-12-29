import asyncio
import os

import httpx
import pytest

from backend.tests.helpers import free_port, start_server, stop_server, wait_ready


async def _consume_stream(response: httpx.Response, meta_event: asyncio.Event) -> None:
    current_event = "message"
    current_data = ""
    async for line in response.aiter_lines():
        if line == "":
            if current_data and current_event == "meta":
                meta_event.set()
            if current_event == "done" or current_event == "error":
                break
            current_event = "message"
            current_data = ""
            continue
        if line.startswith("event:"):
            current_event = line.replace("event:", "").strip()
        elif line.startswith("data:"):
            data_part = line.replace("data:", "").strip()
            if current_data:
                current_data += "\n"
            current_data += data_part


@pytest.mark.integration
@pytest.mark.asyncio
@pytest.mark.skipif(os.getenv("RUN_INTEGRATION") != "1", reason="integration tests disabled")
async def test_active_streams_during_stream():
    port = free_port()
    process = start_server(
        port,
        {
            "MAX_CONCURRENT_STREAMS": "2",
            "RATE_LIMIT_PER_MINUTE": "1000",
            "RATE_LIMIT_PER_DAY": "1000",
            "MODEL_BACKEND": "mock",
        },
    )
    base_url = f"http://127.0.0.1:{port}"
    try:
        await wait_ready(base_url)
        text = "hello " * 200
        meta_event = asyncio.Event()
        async with (
            httpx.AsyncClient(base_url=base_url, timeout=10.0) as client,
            client.stream(
                "POST",
                "/v1/correct/stream",
                json={"text": text, "lang": "tt"},
            ) as response,
        ):
            assert response.status_code == 200
            task = asyncio.create_task(_consume_stream(response, meta_event))
            await asyncio.wait_for(meta_event.wait(), timeout=2.0)

            status = await client.get("/status")
            assert status.status_code == 200
            assert status.json()["active_streams"] >= 1

            await task
    finally:
        stop_server(process)


@pytest.mark.integration
@pytest.mark.asyncio
@pytest.mark.skipif(os.getenv("RUN_INTEGRATION") != "1", reason="integration tests disabled")
async def test_concurrent_stream_limit_live_server():
    port = free_port()
    process = start_server(
        port,
        {
            "MAX_CONCURRENT_STREAMS": "2",
            "RATE_LIMIT_PER_MINUTE": "1000",
            "RATE_LIMIT_PER_DAY": "1000",
            "MODEL_BACKEND": "mock",
        },
    )
    base_url = f"http://127.0.0.1:{port}"
    try:
        await wait_ready(base_url)
        text = "hello " * 200
        meta_one = asyncio.Event()
        meta_two = asyncio.Event()
        async with (
            httpx.AsyncClient(base_url=base_url, timeout=10.0) as client,
            client.stream(
                "POST",
                "/v1/correct/stream",
                json={"text": text, "lang": "tt"},
                headers={"x-forwarded-for": "10.0.0.1"},
            ) as stream_one,
            client.stream(
                "POST",
                "/v1/correct/stream",
                json={"text": text, "lang": "tt"},
                headers={"x-forwarded-for": "10.0.0.1"},
            ) as stream_two,
        ):
            task_one = asyncio.create_task(_consume_stream(stream_one, meta_one))
            task_two = asyncio.create_task(_consume_stream(stream_two, meta_two))
            await asyncio.wait_for(meta_one.wait(), timeout=2.0)
            await asyncio.wait_for(meta_two.wait(), timeout=2.0)

            blocked = await client.post(
                "/v1/correct/stream",
                json={"text": "hello", "lang": "tt"},
                headers={"x-forwarded-for": "10.0.0.1"},
            )
            assert blocked.status_code == 429

            await task_one
            await task_two
    finally:
        stop_server(process)
