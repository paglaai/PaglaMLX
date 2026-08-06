#!/usr/bin/env bash
set -e
REPO_URL="https://github.com/paglaai/PaglaMLX.git"
NEW_BRANCH="pagla-single-commit"
MSG='Initial commit: PaglaMLX rebrand

All previous history squashed into a single commit.

Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>'

echo "Creating orphan branch $NEW_BRANCH and committing current tree..."
git checkout --orphan "$NEW_BRANCH"
# Ensure index is clean for a new orphan branch
git reset --mixed
# Add all files from working tree and commit
git add -A
git commit -m "$MSG"
NEW_COMMIT=$(git rev-parse HEAD)
echo "New root commit: $NEW_COMMIT"

# Move every local branch to point at the new commit
for b in $(git for-each-ref --format='%(refname:short)' refs/heads/); do
  echo "Resetting branch $b -> $NEW_COMMIT"
  git branch -f "$b" "$NEW_COMMIT"
done

# Delete all local tags (to avoid pointing at old history)
TAGS=$(git tag -l)
if [ -n "$TAGS" ]; then
  echo "Deleting local tags..."
  git tag -l | xargs -r git tag -d || true
fi

# Ensure origin exists
if ! git remote | grep -q '^origin$'; then
  git remote add origin "$REPO_URL"
fi

# Force-push all branches to origin and remove tags on remote
echo "Force-pushing branches to origin (this will overwrite remote history)..."
git push --force origin --all

# Delete remote tags by pushing an empty tag set
echo "Deleting remote tags (if any) and pushing local tags (none)..."
git push --force origin --tags || true

# Cleanup
rm -rf .git/refs/original/ || true
git for-each-ref --format='delete %(refname)' refs/original | git update-ref --stdin || true
git gc --prune=now --aggressive || true

echo "History collapse complete."