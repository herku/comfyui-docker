#!/bin/bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
dockerfile=$repo_root/Dockerfile
nodes_file=$repo_root/custom_nodes.txt

changes=()

pinned_comfyui=$(sed -nE 's/^ARG COMFYUI_VERSION=//p' "$dockerfile")
latest_release=$(gh api repos/comfyanonymous/ComfyUI/releases/latest --jq .tag_name)
latest_comfyui=$(printf '%s\n' "$pinned_comfyui" "$latest_release" | sort -V | tail -1)
sed -i.bak -E "s/^ARG COMFYUI_VERSION=.*/ARG COMFYUI_VERSION=$latest_comfyui/" "$dockerfile"
rm "$dockerfile.bak"
if [[ $latest_comfyui != "$pinned_comfyui" ]]; then
  changes+=("ComfyUI to $latest_comfyui")
elif [[ ${BUMP_NODES:-false} != true ]]; then
  echo "ComfyUI $pinned_comfyui is current, skipping custom nodes (set BUMP_NODES=true to force)" >&2
  exit 0
fi

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
  new_commit=${head_commit:-$commit}
  if [[ $new_commit != "$commit" ]]; then
    changes+=("${url##*/} to ${new_commit:0:7}")
  fi
  echo "$url $new_commit" >> "$updated_nodes"
done < "$nodes_file"
mv "$updated_nodes" "$nodes_file"

summary=$(printf '%s, ' "${changes[@]}")
echo "title=Bump ${summary%, }"
