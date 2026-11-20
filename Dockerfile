# syntax=docker/dockerfile:1
FROM python:3.12-slim

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG COMFYUI_VERSION=v0.46.1
ARG TORCH_INDEX_URL=https://download.pytorch.org/whl/cpu

ENV VIRTUAL_ENV=/opt/venv \
    PATH=/opt/venv/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    UV_LINK_MODE=copy \
    UV_NO_CACHE=1 \
    UV_PYTHON=/opt/venv/bin/python \
    UV_CONSTRAINT=/opt/constraints.txt \
    PIP_CONSTRAINT=/opt/constraints.txt \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# hadolint ignore=DL3008
RUN apt-get update \
 && apt-get install -y --no-install-recommends git libgl1 libglib2.0-0 \
 && rm -rf /var/lib/apt/lists/*

RUN PIP_CONSTRAINT= pip install --no-cache-dir uv==0.13.9

RUN useradd --create-home --uid 1000 comfy \
 && mkdir -p /opt/venv /data \
 && touch /opt/constraints.txt \
 && chown comfy:comfy /opt/venv /data /opt/constraints.txt

RUN git clone --depth 1 --branch "$COMFYUI_VERSION" https://github.com/comfyanonymous/ComfyUI /opt/comfyui

COPY custom_nodes.txt /opt/custom_nodes.txt
COPY scripts/clone-custom-nodes.sh /usr/local/bin/clone-custom-nodes
RUN clone-custom-nodes /opt/custom_nodes.txt /opt/comfyui/custom_nodes

USER 1000:1000

RUN python -m venv /opt/venv \
 && uv pip install --index-url "$TORCH_INDEX_URL" torch torchvision torchaudio \
 && python -c "import torch; assert torch.version.cuda is None, torch.version.cuda" \
 && uv pip freeze | grep -E '^(torch|torchvision|torchaudio)==' > /opt/constraints.txt

RUN find /opt/comfyui/custom_nodes -mindepth 2 -maxdepth 2 -name requirements.txt -printf '-r\n%p\n' \
    | xargs uv pip install -r /opt/comfyui/requirements.txt -r /opt/comfyui/manager_requirements.txt \
 && python -c "import torch; assert torch.version.cuda is None, torch.version.cuda"

COPY docker/extra_model_paths.yaml /opt/comfyui/extra_model_paths.yaml
COPY docker/entrypoint.sh /usr/local/bin/entrypoint

WORKDIR /data
VOLUME /data
EXPOSE 8188

HEALTHCHECK --interval=30s --timeout=5s --start-period=120s \
  CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8188/system_stats', timeout=4)"]

ENTRYPOINT ["entrypoint"]
