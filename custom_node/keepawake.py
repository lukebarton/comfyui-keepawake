"""HTTP routes that tell the Windows keep-awake script whether ComfyUI is in use.

The browser script (web/keepawake.js) POSTs /keepawake/ping about once a minute while someone is
using the page. The Windows script polls GET /keepawake/status. The status format is documented
in the README; change it there too.
"""

import time

from aiohttp import web
from server import PromptServer

# Server time (Unix seconds) of the most recent ping, or None if none since ComfyUI started.
_last_ping = None

routes = PromptServer.instance.routes


@routes.post("/keepawake/ping")
async def ping(request):
    global _last_ping
    _last_ping = time.time()
    return web.json_response({"last_ping": _last_ping})


@routes.get("/keepawake/status")
async def status(request):
    running, queued = PromptServer.instance.prompt_queue.get_current_queue()
    return web.json_response(
        {
            "last_ping": _last_ping,
            "jobs_running": len(running),
            "jobs_queued": len(queued),
            "busy": bool(running or queued),
            "server_time": time.time(),
        },
        headers={"Cache-Control": "no-store"},
    )
