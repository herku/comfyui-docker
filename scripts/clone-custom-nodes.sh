#!/bin/sh
set -eu

list_file=$1
target_dir=$2

grep -Ev '^[[:space:]]*(#|$)' "$list_file" | while read -r url commit; do
  name=$(basename "$url" .git)
  dest="$target_dir/$name"
  git init --quiet "$dest"
  git -C "$dest" fetch --quiet --depth 1 "$url" "$commit"
  git -C "$dest" -c advice.detachedHead=false checkout --quiet FETCH_HEAD
  rm -rf "$dest/.git"
  echo "cloned $name@$commit"
done
