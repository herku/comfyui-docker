#!/bin/bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
dockerfile=$repo_root/Dockerfile
nodes_file=$repo_root/custom_nodes.txt

latest_comfyui=$(gh api repos/comfyanonymous/ComfyUI/releases/latest --jq .tag_name)
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
