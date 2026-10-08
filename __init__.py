# ComfyUI-Manager installs a node by cloning its whole repo into custom_nodes/, and ComfyUI then
# loads the __init__.py at the top of the clone. This file points ComfyUI at the node in custom_node/.
from .custom_node import NODE_CLASS_MAPPINGS

# ComfyUI resolves WEB_DIRECTORY relative to this file, so it has to name the subfolder.
WEB_DIRECTORY = "./custom_node/web"

__all__ = ["NODE_CLASS_MAPPINGS", "WEB_DIRECTORY"]
