#!/bin/bash
# Get commit data from GitHub API

set -e

OUTPUT_FILE="$1"

echo "[]" > "$OUTPUT_FILE"

if command -v gh &> /dev/null; then
  WORKFLOW_ID=$(gh api "repos/${GITHUB_REPOSITORY_OWNER}/${REPO_NAME}/actions/runs/${GITHUB_RUN_ID}" --jq '.workflow_id' 2>/dev/null || echo "")

  if [ -n "$WORKFLOW_ID" ]; then
    PREVIOUS_SHA=$(gh api "repos/${GITHUB_REPOSITORY_OWNER}/${REPO_NAME}/actions/workflows/${WORKFLOW_ID}/runs?branch=${GITHUB_REF_NAME}&status=success&per_page=1" \
      --jq '.workflow_runs[0].head_sha // empty' 2>/dev/null || echo "")

    if [ -n "$PREVIOUS_SHA" ] && [ "$PREVIOUS_SHA" != "$GITHUB_SHA" ]; then
      COMMITS_JSON=$(gh api "repos/${GITHUB_REPOSITORY_OWNER}/${REPO_NAME}/compare/${PREVIOUS_SHA}...${GITHUB_SHA}" \
        --jq '[.commits[] | {sha: .sha, message: .commit.message, author: .commit.author.name}]' 2>/dev/null || echo "[]")

      if [ "$COMMITS_JSON" != "[]" ] && [ -n "$COMMITS_JSON" ]; then
        echo "$COMMITS_JSON" > "$OUTPUT_FILE"
        echo "PREVIOUS_SHA=$PREVIOUS_SHA" >> "${OUTPUT_FILE}.meta"
        echo "CURRENT_SHA=$GITHUB_SHA" >> "${OUTPUT_FILE}.meta"
      fi
    fi
  fi
fi
