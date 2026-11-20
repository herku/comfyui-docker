import os
import urllib.request

host = os.environ.get("COMFYUI_LISTEN", "0.0.0.0").split(",")[0].strip()
if host in ("", "0.0.0.0", "::"):
    host = "127.0.0.1"
if ":" in host:
    host = f"[{host}]"
port = os.environ.get("COMFYUI_PORT", "8188")
urllib.request.urlopen(f"http://{host}:{port}/system_stats", timeout=4)
