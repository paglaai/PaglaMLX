#!/usr/bin/env bash
set -e

echo "Starting git filter-branch to replace 'LengtaMLX' with 'PaglaMLX' across history..."

git filter-branch --force --tag-name-filter cat \
  --msg-filter 'sed -e "s/LengtaMLX/PaglaMLX/g"' \
  --tree-filter 'git ls-files -z | xargs -0 sed -i "s/LengtaMLX/PaglaMLX/g" || true' \
  -- --all

echo "Removing backup refs and garbage collecting..."
rm -rf .git/refs/original/ || true
git for-each-ref --format='delete %(refname)' refs/original | git update-ref --stdin || true
git gc --prune=now --aggressive || true

echo "Done."