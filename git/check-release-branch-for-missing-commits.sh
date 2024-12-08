#!/bin/bash
#set -xe
# This script can uncover contribitor commits that were not cherry-picked into a hotfix release branch, causing additional merge conflicts or missing work.Assumes branch merge strategy: Squash and merge.
REPO="the-org-and-repo-goes-here"
RELEASE_BRANCH="release/app_x.x.x"
DEVELOP_BRANCH="develop"

# String to store summaries
summary_missing_cherry_pick_body=""

for AUTHOR in "${AUTHORS[@]}"; do
  echo "Processing author: $AUTHOR"

  # Fetch all commits on the release branch by the specified author
  release_commits=$(gh api -X GET repos/$REPO/commits --jq '.[] | select(.commit.author.name == "'"$AUTHOR"'") | .sha' -f sha=$RELEASE_BRANCH)

  # Convert release commits to an array
  release_commits_array=($release_commits)

  # Check each release commit for missing cherry-pick body
  for release_commit in "${release_commits_array[@]}"; do
    # Fetch the commit message
    commit_message=$(gh api repos/$REPO/commits/$release_commit --jq '.commit.message')

    # Check if the commit message is missing a cherry-pick reference
    if [[ ! $commit_message == *"(cherry picked from commit"* ]]; then
      # Check if the release commit hash is referenced in any develop branch commit messages
      develop_commits=$(gh api -X GET repos/$REPO/commits --jq '.[] | select(.commit.message | contains("'"$release_commit"'")) | .sha' -f sha=$DEVELOP_BRANCH)

      if [[ -z $develop_commits ]]; then
        # Remove cherry-pick references and normalize whitespace from the commit message for comparison
        clean_commit_message=$(echo "$commit_message" | sed 's/(cherry picked from commit [0-9a-f]\{40\})//g; s/(develop)//g; s/(release)//g; s/[[:space:]]\+/ /g')

        # Fetch all commit messages from the develop branch
        develop_messages=$(gh api -X GET repos/$REPO/commits --jq '.[] | .commit.message' -f sha=$DEVELOP_BRANCH)

        match_found=false
        while read -r develop_message; do
          clean_develop_message=$(echo "$develop_message" | sed 's/(cherry picked from commit [0-9a-f]\{40\})//g; s/(develop)//g; s/(release)//g; s/[[:space:]]\+/ /g')
          if [[ "$clean_commit_message" == "$clean_develop_message" ]]; then
            match_found=true
            break
          fi
        done <<< "$develop_messages"

        # If no matching commit message is found, add to summary
        if [[ "$match_found" == false ]]; then
          summary_missing_cherry_pick_body+="$AUTHOR: $release_commit\n"
        fi
      fi
    fi
  done
done

# Print summary
echo "Summary of commits missing cherry-pick body:"
echo -e "$summary_missing_cherry_pick_body"
