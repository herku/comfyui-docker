#!/bin/bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
dockerfile=$repo_root/Dockerfile
nodes_file=$repo_root/custom_nodes.txt

pinned_comfyui=$(sed -nE 's/^ARG COMFYUI_VERSION=//p' "$dockerfile")
latest_release=$(gh api repos/comfyanonymous/ComfyUI/releases/latest --jq .tag_name)
latest_comfyui=$(printf '%s\n' "$pinned_comfyui" "$latest_release" | sort -V | tail -1)
sed -i.bak -E "s/^ARG COMFYUI_VERSION=.*/ARG COMFYUI_VERSION=$latest_comfyui/" "$dockerfile"
rm "$dockerfile.bak"

updated_nodes=$(mktemp)
while read -r url commit; do
  if [[ -z $url || $url == \#* ]]; then
    echo "$url${commit:+ $commit}" >> "$updated_nodes"
    continue
  fi
  if ! head_commit=$(GIT_TERMINAL_PROMPT=0 git ls-remote "$url" HEAD | cut -f1); then
    echo "WARNING: cannot reach $url, keeping $commit" >&2
    head_commit=
  fi
  echo "$url ${head_commit:-$commit}" >> "$updated_nodes"
done < "$nodes_file"
mv "$updated_nodes" "$nodes_file"

echo "comfyui=$latest_comfyui"
