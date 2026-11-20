#!/bin/bash
set -euo pipefail

data_dir=/data
runtime_nodes_dir=$data_dir/custom_nodes
deps_marker=/opt/venv/.runtime-custom-nodes-deps.sha256

mkdir -p "$runtime_nodes_dir" "$data_dir/user" "$data_dir/input" "$data_dir/output" "$data_dir/models"

restore_runtime_node_deps() {
  shopt -s nullglob
  local requirement_files=("$runtime_nodes_dir"/*/requirements.txt)
  shopt -u nullglob
  ((${#requirement_files[@]})) || return 0

  local digest
  digest=$(cat "${requirement_files[@]}" | sha256sum | cut -d' ' -f1)
  [[ -f $deps_marker && $(<"$deps_marker") == "$digest" ]] && return 0

  echo "[entrypoint] installing dependencies of Manager-installed custom nodes"
  local args=()
  for file in "${requirement_files[@]}"; do args+=(-r "$file"); done
  if uv pip install "${args[@]}"; then
    echo "$digest" > "$deps_marker"
  else
    echo "[entrypoint] WARNING: dependency install failed, affected nodes may not load" >&2
  fi
}

restore_runtime_node_deps

exec python /opt/comfyui/main.py \
  --base-directory "$data_dir" \
  --listen "${COMFYUI_LISTEN:-0.0.0.0}" \
  --port "${COMFYUI_PORT:-8188}" \
  --cpu \
  --enable-manager \
  "$@"
