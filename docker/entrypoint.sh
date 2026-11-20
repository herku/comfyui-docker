#!/bin/bash
set -euo pipefail

data_dir=/data
runtime_nodes_dir=$data_dir/custom_nodes
deps_state_dir=/opt/venv/.runtime-custom-nodes-deps

mkdir -p "$runtime_nodes_dir" "$data_dir/user" "$data_dir/input" "$data_dir/output" "$data_dir/models"

restore_runtime_node_deps() {
  shopt -s nullglob
  local requirement_files=("$runtime_nodes_dir"/*/requirements.txt)
  shopt -u nullglob
  mkdir -p "$deps_state_dir"

  local file node digest marker
  for file in "${requirement_files[@]}"; do
    node=$(basename "$(dirname "$file")")
    digest=$(sha256sum "$file" | cut -d' ' -f1)
    marker=$deps_state_dir/$node.sha256
    [[ -f $marker && $(<"$marker") == "$digest" ]] && continue

    echo "[entrypoint] installing dependencies of custom node $node"
    if uv pip install -r "$file"; then
      echo "$digest" > "$marker"
    else
      echo "[entrypoint] WARNING: dependency install failed for custom node $node, it may not load" >&2
    fi
  done
}

enforce_manager_security() {
  local network_mode=public
  [[ ${COMFYUI_MANAGER_REMOTE_INSTALLS:-false} == true ]] && network_mode=personal_cloud
  python - "$data_dir/user/__manager/config.ini" "$network_mode" <<'PY'
import configparser, os, sys
path, network_mode = sys.argv[1], sys.argv[2]
os.makedirs(os.path.dirname(path), exist_ok=True)
config = configparser.ConfigParser(strict=False)
try:
    config.read(path)
except (configparser.Error, UnicodeDecodeError) as error:
    print(f"[entrypoint] WARNING: {path} is malformed ({error}), moving it to {path}.corrupt", file=sys.stderr)
    os.replace(path, path + ".corrupt")
    config = configparser.ConfigParser(strict=False)
if not config.has_section("default"):
    config.add_section("default")
config["default"]["network_mode"] = network_mode
config["default"]["security_level"] = "normal"
with open(path, "w") as f:
    config.write(f)
PY
}

restore_runtime_node_deps
enforce_manager_security

exec python /opt/comfyui/main.py \
  --base-directory "$data_dir" \
  --listen "${COMFYUI_LISTEN:-0.0.0.0}" \
  --port "${COMFYUI_PORT:-8188}" \
  --cpu \
  --enable-manager \
  "$@"
