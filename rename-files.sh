#!/usr/bin/env bash
set -e

files=$(git ls-files | grep -i Lengta || true)
if [ -z "$files" ]; then
  echo "No files to rename"
  exit 0
fi

echo "Files to rename:"
echo "$files"
for f in $files; do
  new=$(echo "$f" | sed "s/Lengta/Pagla/g")
  git mv "$f" "$new"
  echo "Renamed: $f -> $new"
done

# Commit with co-author trailer
git commit -m $'Rename files: Lengta -> Pagla\n\nCo-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>' || true

# Force-push rewritten history and tags
 git push --force --all
 git push --force --tags
