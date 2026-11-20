# comfyui-api

ComfyUI image for hosted API models only. CPU-only torch, no model downloads, multi-arch (`linux/amd64`, `linux/arm64`), published to `ghcr.io/herku/comfyui-api`.

## Included nodes

| Source | Nodes | Billing / key |
| --- | --- | --- |
| ComfyUI partner nodes (built in) | OpenAI, Gemini, Kling, Runway, Flux Pro, Luma, and others | Comfy.org credits |
| [ComfyUI-fal-API](https://github.com/gokayfem/ComfyUI-fal-API) | fal.ai catalog | `FAL_KEY` |
| [ComfyUI-ExternalAPI-Helpers](https://github.com/Aryan185/ComfyUI-ExternalAPI-Helpers) | OpenAI, Gemini/Imagen/Veo, Flux on Replicate, xAI, Groq, ElevenLabs, Tripo | `OPENAI_API_KEY`, `GEMINI_API_KEY`, `REPLICATE_API_TOKEN`, `XAI_API_KEY`, `GROQ_API_KEY`, `XI_API_KEY`, `TRIPO_API_KEY` |
| ComfyUI-Manager | install more nodes at runtime | - |

Pinned packs are listed in `custom_nodes.txt` (`<git url> <commit>`).

## Run

```sh
cp .env.example .env   # fill in the keys you use
docker compose up -d
```

UI and HTTP API on `127.0.0.1:8188` (compose binds loopback only; point your reverse proxy at it, or change the port mapping deliberately). All state lives in the `/data` volume: `user/` (workflows, settings, Manager config), `input/`, `output/`, `custom_nodes/` (Manager-installed nodes).

### Partner node login

Comfy.org account sign-in only works on `localhost`. On any other host, choose **Comfy API Key** on the login dialog and paste a key from <https://platform.comfy.org/login>.

Headless: add the key to the `/prompt` payload:

```json
{ "prompt": { ... }, "extra_data": { "api_key_comfy_org": "comfyui-..." } }
```

## Security

The image ships no authentication. Put it behind a reverse proxy with auth before exposing it. Anyone who reaches port 8188 can spend your API credits, read outputs and, through ComfyUI-Manager, install code that can read every key in the environment.

## Manager-installed nodes

Node folders persist in `/data/custom_nodes`. Their Python dependencies live in the image venv, so the entrypoint reinstalls them on the first start of a new container. To make a node permanent, add it to `custom_nodes.txt`.

## CI

- `build.yml`: on PR, builds both arches on native runners and runs `scripts/smoke-test.sh` (checks node classes per pack, import failures, Manager). Only on `main` does it push `:latest`, `:<comfyui-version>` and `:<comfyui-version>-<sha>`.
- `bump.yml`: daily, bumps `COMFYUI_VERSION` to the latest ComfyUI release and the node pins to their HEAD, opens a PR on `bump/upstream`, then dispatches `build.yml` on that branch (build and smoke test only, no push).

Repo settings required: Settings > Actions > General > Workflow permissions: enable "Allow GitHub Actions to create and approve pull requests".
