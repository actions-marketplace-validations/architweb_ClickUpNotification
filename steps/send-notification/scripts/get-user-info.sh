#!/bin/bash
# Get GitHub user information

set -e

OUTPUT_FILE="$1"

# Get user name with fallback
TRIGGERING_USER_NAME=""
if [ -n "$GITHUB_TOKEN" ] && [ -n "$TRIGGERING_ACTOR" ]; then
  TRIGGERING_USER_NAME=$(curl -sf -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/users/${TRIGGERING_ACTOR}" 2>/dev/null | jq -r '.name // ""' 2>/dev/null || echo "")
fi

if [ -z "$TRIGGERING_USER_NAME" ] || [ "$TRIGGERING_USER_NAME" = "null" ]; then
    TRIGGERING_USER_NAME="${TRIGGERING_ACTOR:-Unknown User}"
fi

# Ensure the user name is properly quoted and sanitized
TRIGGERING_USER_NAME=$(printf '%s' "$TRIGGERING_USER_NAME" | tr -c '[:alnum:] ' ' ' | tr -s ' ')

echo "TRIGGERING_USER_NAME=\"$TRIGGERING_USER_NAME\"" > "$OUTPUT_FILE"
