#!/usr/bin/env bash
# Split one or more packages out of a monorepo into a new GitHub repository,
# preserving git history via `git filter-repo`.
#
# Fill in to_copy (paths kept in the NEW repo) and to_delete (paths removed from
# the CURRENT repo) before running — they are kept separate on purpose, since
# some paths may be duplicated into the new repo without being removed here.
# Both repositories must already exist on GitHub.
#
# Requires: git-filter-repo (brew install git-filter-repo).

set -euo pipefail

GITHUB_ORG_NAME="org"
REPOSITORY_CURRENT="repo-current"
REPOSITORY_NEW="repo-new"

REPO_CURRENT_BRANCH="chore/repo-current"
REPO_NEW_BRANCH="chore/repo-new" # suggest using `develop` after done testing

# TODO: paths to carve into the new repo, e.g. to_copy=("packages/foo" "libs/shared")
to_copy=()

# TODO: paths to remove from the current repo (often the same set as to_copy)
to_delete=()

if ! command -v git-filter-repo >/dev/null 2>&1; then
  echo "error: git-filter-repo not found (brew install git-filter-repo)" >&2
  exit 1
fi
if [ ${#to_copy[@]} -eq 0 ]; then
  echo "error: to_copy is empty; set the paths to carve into $REPOSITORY_NEW" >&2
  exit 1
fi

current_url="git@github.com:$GITHUB_ORG_NAME/$REPOSITORY_CURRENT.git"
new_url="git@github.com:$GITHUB_ORG_NAME/$REPOSITORY_NEW.git"

# --- Build the new repo: clone current, strip down to to_copy with history ---
rm -rf "$REPOSITORY_NEW" repo-current-temp
git clone -b "$REPO_CURRENT_BRANCH" "$current_url" "$REPOSITORY_NEW"
cd "$REPOSITORY_NEW"

filter_args=()
for path in "${to_copy[@]}"; do
  filter_args+=(--path "$path")
done
git filter-repo "${filter_args[@]}"
tree -L 2 2>/dev/null || true

npm ci
npm run build
npm run test

# filter-repo drops the origin remote; repoint at the new repo.
git remote remove origin 2>/dev/null || true
git remote add origin "$new_url"

if ! git show-ref --quiet "refs/heads/$REPO_NEW_BRANCH"; then
  git branch "$REPO_NEW_BRANCH"
fi
git push --set-upstream origin "$REPO_NEW_BRANCH"

# --- Prune the carved paths out of the current repo ---
cd ..
git clone -b "$REPO_CURRENT_BRANCH" "$current_url" repo-current-temp
cd repo-current-temp

if [ ${#to_delete[@]} -gt 0 ]; then
  git rm -rf "${to_delete[@]}"
fi
npm ci
npm run build
npm run lint
npm run test

git commit -m "chore: split repository"
git push origin "$REPO_CURRENT_BRANCH"
