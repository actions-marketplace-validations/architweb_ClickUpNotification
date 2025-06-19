#!/bin/bash
# Resolve workspace and channel names from IDs

set -e

API_TOKEN="$1"
WORKSPACE_ID="$2"
OUTPUT_FILE="$3"

# Default to IDs, but handle masked values
WORKSPACE_NAME="$WORKSPACE_ID"

# Don't try to resolve if token or IDs are masked
if [ "$API_TOKEN" = "***" ] || [ "$WORKSPACE_ID" = "***" ]; then
  echo "WORKSPACE_NAME=$WORKSPACE_NAME" >"$OUTPUT_FILE"
  exit 0
fi

# Try to resolve workspace name from teams API
TEAMS_RESPONSE=$(curl -s -H "Authorization: $API_TOKEN" \
  "https://api.clickup.com/api/v2/team" 2>/dev/null || echo "")

if [ -n "$TEAMS_RESPONSE" ]; then
  RESOLVED_NAME=$(echo "$TEAMS_RESPONSE" | jq -r ".teams[] | select(.id == \"$WORKSPACE_ID\") | .name" 2>/dev/null || echo "")

  if [ -n "$RESOLVED_NAME" ] && [ "$RESOLVED_NAME" != "null" ]; then
    WORKSPACE_NAME="$RESOLVED_NAME"
  fi
fi

# Output results
echo "WORKSPACE_NAME=$WORKSPACE_NAME" >"$OUTPUT_FILE"
