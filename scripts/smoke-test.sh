#!/bin/bash
set -euo pipefail

image=$1
port=${2:-18188}
container=comfyui-smoke-$$
expected_nodes=(
  OpenAIGPTImage1
  GeminiImageNode
  FluxPro_fal
  Flux2Replicate
  OpenAILLMNode
  NanoBananaNode
)

cleanup() {
  docker logs "$container" > smoke-test.log 2>&1 || true
  docker rm -fv "$container" > /dev/null 2>&1 || true
}
trap cleanup EXIT

docker run -d --name "$container" -p "127.0.0.1:$port:8188" "$image" > /dev/null

for _ in $(seq 1 120); do
  curl -fsS "http://127.0.0.1:$port/system_stats" > /dev/null 2>&1 && break
  sleep 2
done
curl -fsS "http://127.0.0.1:$port/system_stats" > /dev/null

object_info=$(curl -fsS "http://127.0.0.1:$port/object_info")
missing=()
for node in "${expected_nodes[@]}"; do
  jq -e --arg n "$node" 'has($n)' <<< "$object_info" > /dev/null || missing+=("$node")
done

container_log=$(docker logs "$container" 2>&1)
if grep -q "IMPORT FAILED" <<< "$container_log"; then
  grep -B2 -A2 "IMPORT FAILED" <<< "$container_log" >&2
  echo "custom node import failure" >&2
  exit 1
fi

if ((${#missing[@]})); then
  echo "missing nodes: ${missing[*]}" >&2
  exit 1
fi

docker exec -w /opt/comfyui "$container" python -c "import comfyui_manager" \
  || { echo "ComfyUI-Manager not importable" >&2; exit 1; }
grep -q "\[START\] ComfyUI-Manager" <<< "$container_log" \
  || { echo "ComfyUI-Manager did not start" >&2; exit 1; }

manager_config=$(docker exec "$container" cat /data/user/__manager/config.ini)
for setting in "network_mode = public" "security_level = normal"; do
  grep -qx "$setting" <<< "$manager_config" \
    || { echo "Manager config missing '$setting': $manager_config" >&2; exit 1; }
done

echo "smoke test passed: $(jq 'length' <<< "$object_info") node classes"
