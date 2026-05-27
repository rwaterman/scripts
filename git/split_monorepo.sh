#!/bin/bash
# - This script will split one or more mono-repository packages into a new Github repository. It requires some manual work to update the to_copy and to_delete sections
# - It ensures to keep Git History and is why you would use it
# - There will be some duplication depending upon your Monorepo structure

# Define the branch name as an environment variable
GITHUB_ORG_NAME="org"
REPOSITORY_CURRENT="repo-current"
REPOSITORY_NEW="repo-new"

REPO_CURRENT_BRANCH="chore/repo-current"
REPO_NEW_BRANCH="chore/repo-new" REPO_NEW_BRANCH="chore/repo-new" # suggest using `develop` after done testing

rm -rf "$REPOSITORY_NEW" "$REPOSITORY_CURRENT"
git clone -b "$REPO_CURRENT_BRANCH" "git@github.com:$GITHUB_ORG_NAME/$REPOSITORY_CURRENT.git" "$REPOSITORY_NEW"
cd "$REPOSITORY_NEW" || exit 1

# TODO: Must add files and directories manually
to_copy=()

# Run git filter-repo with the paths
git filter-repo $(printf -- '--path %s ' "${to_copy[@]// #*/}") || exit 1
tree -L2
npm ci || exit 1
npm run build || exit 1
npm run test || exit 1

# Repoint the repository to repo-new
git remote add origin "git@github.com:$GITHUB_ORG_NAME/$REPOSITORY_NEW.git"
git remote set-url origin "git@github.com:$GITHUB_ORG_NAME/$REPOSITORY_NEW.git" || exit 1

# Check if the new branch exists and create it if it doesn't
if ! git show-ref --quiet refs/heads/"$REPO_NEW_BRANCH"; then
  git branch "$REPO_NEW_BRANCH" || exit 1
fi
# Push the changes to the new branch
git push --set-upstream origin "$REPO_NEW_BRANCH" || exit 1

cd ..
git clone -b "$REPO_CURRENT_BRANCH" "git@github.com:$GITHUB_ORG_NAME/$REPOSITORY_CURRENT.git" repo-current-temp || exit 1
cd repo-current-temp || exit 1

# TODO: Must add files and directories manually
to_delete=()

# Remove each path using git rm -rf
for path in "${to_delete[@]}"; do
  git rm -rf "$path"
done
npm ci || exit 1
npm run build || exit 1
npm run lint || exit 1
npm run test || exit 1

# Commit the changes
git commit -m "chore: split repository"
git push "$REPO_CURRENT_BRANCH"
