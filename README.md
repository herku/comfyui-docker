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
cp .env.example .env                  # TUNNEL_TOKEN only, read by compose for cloudflared
cp comfyui.env.example comfyui.env    # provider keys, passed to ComfyUI only
docker compose up -d
```

ComfyUI publishes no host port. The only way in is the Cloudflare Tunnel, gated by Cloudflare Access. The tunnel token is kept out of the ComfyUI container so custom nodes cannot read it.

All state lives in the `/data` volume: `user/` (workflows, settings, Manager config), `input/`, `output/`, `custom_nodes/` (Manager-installed nodes).

Local test without the tunnel: `docker run --rm -p 127.0.0.1:8188:8188 --env-file comfyui.env ghcr.io/herku/comfyui-api:latest`, then open http://127.0.0.1:8188.

### Cloudflare setup (one-off)

Requires a domain on Cloudflare DNS. Below, `comfy.example.com` stands for your hostname.

1. Cloudflare dashboard > Zero Trust > Networks > Tunnels > Create a tunnel > Cloudflared. Name it `comfyui`.
2. On the install step, copy the token from the shown command (the long string after `--token`) into `.env` as `TUNNEL_TOKEN=`.
3. Next > Public hostname: subdomain `comfy`, domain `example.com`, service type `HTTP`, URL `comfyui:8188`. Save.
4. Zero Trust > Access > Service credentials > Service Tokens > Create. Name `comfyui-scripts`. Copy Client ID and Client Secret (the secret is shown once).
5. Zero Trust > Access > Applications > Add an application > Self-hosted. Name `ComfyUI`, domain `comfy.example.com`, session duration `24 hours`.
6. Add policy `owner`: action `Allow`, include `Emails` = your email address. Login method: One-time PIN.
7. Add policy `scripts`: action `Service Auth`, include `Service Token` = `comfyui-scripts`.
8. Save the application, open it again and copy the **Application Audience (AUD) Tag**.
9. Zero Trust > Networks > Tunnels > `comfyui` > Public hostname `comfy.example.com` > Edit > Additional application settings > Access: enable **Protect with Access** (labelled "Enforce Access JSON Web Token (JWT) validation" in some dashboard versions), team name = your Zero Trust team name, AUD tag from step 8. Save. cloudflared now rejects any request without a valid Access token.
10. `docker compose up -d`, open https://comfy.example.com, sign in with the emailed PIN. Confirm a private window without the PIN gets the Access login page.
11. Only now, to allow Manager installs: set `COMFYUI_MANAGER_REMOTE_INSTALLS=true` in `comfyui.env`, then `docker compose up -d`.

Scripts call the API with the service token:

```sh
curl https://comfy.example.com/system_stats \
  -H "CF-Access-Client-Id: $CF_ACCESS_CLIENT_ID" \
  -H "CF-Access-Client-Secret: $CF_ACCESS_CLIENT_SECRET"
```

### Partner node login

Comfy.org account sign-in only works on `localhost`. On any other host, choose **Comfy API Key** on the login dialog and paste a key from <https://platform.comfy.org/login>.

Headless: add the key to the `/prompt` payload:

```json
{ "prompt": { ... }, "extra_data": { "api_key_comfy_org": "comfyui-..." } }
```

## Security

- Every custom node runs inside the ComfyUI process and can read every key in `comfyui.env`. Access keeps strangers out; it does not protect keys from a malicious node you install yourself.
- The entrypoint rewrites ComfyUI-Manager's `network_mode` and `security_level = normal` on every start. Default `network_mode = public`: Manager refuses all installs. Set `COMFYUI_MANAGER_REMOTE_INSTALLS=true` in `comfyui.env` only after Cloudflare setup step 9 is done: it switches to `personal_cloud`, which allows installs from the Manager registry while still blocking arbitrary git URLs and pip specs.
- Prefer adding nodes to `custom_nodes.txt` (reviewed, pinned, smoke-tested in CI) over installing them in the UI.

## Manager-installed nodes

Node folders persist in `/data/custom_nodes`. Their Python dependencies live in the image venv, so the entrypoint reinstalls them on the first start of a new container. To make a node permanent, add it to `custom_nodes.txt`.

## CI

- `build.yml`: on PR, builds both arches on native runners and runs `scripts/smoke-test.sh` (checks node classes per pack, import failures, Manager). Only on `main` does it push `:latest`, `:<comfyui-version>` and `:<comfyui-version>-<sha>`.
- `bump.yml`: daily, bumps `COMFYUI_VERSION` to the latest ComfyUI release and the node pins to their HEAD, opens a PR on `bump/upstream`, builds and smoke tests that branch, squash-merges the PR on success, then dispatches `build.yml` on `main` to publish the image.

Repo settings required: Settings > Actions > General > Workflow permissions: enable "Allow GitHub Actions to create and approve pull requests".
