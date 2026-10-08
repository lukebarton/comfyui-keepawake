import pytest
from aiohttp import web
from conftest import FakePromptQueue, FakePromptServer

from custom_node import keepawake


@pytest.fixture
def queue(monkeypatch):
    queue = FakePromptQueue()
    monkeypatch.setattr(FakePromptServer.instance, "prompt_queue", queue)
    monkeypatch.setattr(keepawake, "_last_ping", None)
    return queue


@pytest.fixture
async def client(aiohttp_client, queue):
    app = web.Application()
    app.add_routes(FakePromptServer.instance.routes)
    return await aiohttp_client(app)


@pytest.fixture
def clock(monkeypatch):
    now = {"t": 1000.0}
    monkeypatch.setattr(keepawake.time, "time", lambda: now["t"])
    return now


async def test_status_before_any_ping(client, clock):
    resp = await client.get("/keepawake/status")
    assert resp.status == 200
    assert await resp.json() == {
        "last_ping": None,
        "jobs_running": 0,
        "jobs_queued": 0,
        "busy": False,
        "server_time": 1000.0,
    }


async def test_ping_is_reported_in_status(client, clock):
    await client.post("/keepawake/ping")
    clock["t"] = 1090.0
    body = await (await client.get("/keepawake/status")).json()
    assert body["last_ping"] == 1000.0
    assert body["server_time"] == 1090.0


@pytest.mark.parametrize(
    "running, queued, busy",
    [
        ([], [], False),
        (["job"], [], True),
        ([], ["job"], True),
        (["a"], ["b", "c"], True),
    ],
)
async def test_busy_when_a_job_is_running_or_queued(
    client, queue, running, queued, busy
):
    queue.running, queue.queued = running, queued
    body = await (await client.get("/keepawake/status")).json()
    assert body["jobs_running"] == len(running)
    assert body["jobs_queued"] == len(queued)
    assert body["busy"] is busy
