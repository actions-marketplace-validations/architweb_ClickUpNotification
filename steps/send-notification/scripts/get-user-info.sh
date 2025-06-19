#!/bin/bash
# Get GitHub user information

set -e

OUTPUT_FILE="$1"

TRIGGERING_USER_NAME=$(curl -sf -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/users/${TRIGGERING_ACTOR}" | jq -r '.name // ""')

if [ -z "$TRIGGERING_USER_NAME" ]; then
    TRIGGERING_USER_NAME="${TRIGGERING_ACTOR}"
fi

echo "TRIGGERING_USER_NAME=$TRIGGERING_USER_NAME" > "$OUTPUT_FILE"
