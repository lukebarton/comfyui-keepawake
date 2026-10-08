import sys
import types
from pathlib import Path

from aiohttp import web

# The custom node imports ComfyUI's `server` module, which only exists inside ComfyUI.
# Stand in for the parts it uses: the route table and the prompt queue.


class FakePromptQueue:
    def __init__(self):
        self.running = []
        self.queued = []

    def get_current_queue(self):
        return list(self.running), list(self.queued)


class FakePromptServer:
    instance = types.SimpleNamespace(
        routes=web.RouteTableDef(), prompt_queue=FakePromptQueue()
    )


sys.modules["server"] = types.SimpleNamespace(PromptServer=FakePromptServer)
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
