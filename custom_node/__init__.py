# Adds no nodes to the graph. Importing keepawake registers the /keepawake HTTP routes, and
# WEB_DIRECTORY makes ComfyUI serve the browser script that sends the pings.
from . import keepawake  # noqa: F401

# ComfyUI skips (and warns about) a custom node folder that has no NODE_CLASS_MAPPINGS.
NODE_CLASS_MAPPINGS = {}
WEB_DIRECTORY = "./web"

__all__ = ["NODE_CLASS_MAPPINGS", "WEB_DIRECTORY"]
