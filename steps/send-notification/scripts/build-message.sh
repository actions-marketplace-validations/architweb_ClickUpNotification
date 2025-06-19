#!/bin/bash
# Build the notification message

set -e

USER_INFO_FILE="$1"
TITLE="$2"
DESCRIPTION="$3"
FORMATTED_DURATION="$4"
COMMIT_FILE="$5"
OUTPUT_FILE="$6"

# Load user info
source "$USER_INFO_FILE"

# Build base message
if [ -n "$TITLE" ]; then
  BASE_MESSAGE="🚀 **${GITHUB_REF_NAME}** | **${CLICKUP_PROJECT_NAME}** | $TITLE"
else
  BASE_MESSAGE="🚀 **${CLICKUP_PROJECT_NAME}** deployed to **${GITHUB_REF_NAME}**"
fi

DEPLOY_INFO="_Triggered by: ${TRIGGERING_USER_NAME}"
[ "$FORMATTED_DURATION" != "unknown" ] && DEPLOY_INFO="${DEPLOY_INFO}, Done in: ${FORMATTED_DURATION}min_"
[ "$FORMATTED_DURATION" == "unknown" ] && DEPLOY_INFO="${DEPLOY_INFO}_"

if [ -n "$DESCRIPTION" ]; then
  FINAL_MESSAGE="${BASE_MESSAGE}\n\n${DEPLOY_INFO}\n\n_${DESCRIPTION}_"
else
  FINAL_MESSAGE="${BASE_MESSAGE}\n\n${DEPLOY_INFO}"
fi

# Add commit information if available
if [ -f "$COMMIT_FILE" ] && [ -s "$COMMIT_FILE" ]; then
  COMMIT_LIST=$(cat "$COMMIT_FILE")
  if [ -n "$COMMIT_LIST" ]; then
    FINAL_MESSAGE="${FINAL_MESSAGE}${COMMIT_LIST}"
  fi
fi

echo -e "$FINAL_MESSAGE" > "$OUTPUT_FILE"
