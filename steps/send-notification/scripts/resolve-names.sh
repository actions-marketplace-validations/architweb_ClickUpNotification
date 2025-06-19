#!/bin/bash
# Resolve workspace and channel names from IDs

set -e

API_TOKEN="$1"
WORKSPACE_ID="$2"
CHANNEL_ID="$3"
OUTPUT_FILE="$4"

# Default to IDs
WORKSPACE_NAME="$WORKSPACE_ID"
CHANNEL_NAME="$CHANNEL_ID"

# Try to resolve workspace name from teams API
TEAMS_RESPONSE=$(curl -s -H "Authorization: $API_TOKEN" \
  "https://api.clickup.com/api/v2/team" 2>/dev/null || echo "")

if [ -n "$TEAMS_RESPONSE" ]; then
  RESOLVED_NAME=$(echo "$TEAMS_RESPONSE" | jq -r ".teams[] | select(.id == \"$WORKSPACE_ID\") | .name" 2>/dev/null || echo "")
  if [ -n "$RESOLVED_NAME" ] && [ "$RESOLVED_NAME" != "null" ]; then
    WORKSPACE_NAME="$RESOLVED_NAME"
  fi
fi

# Try to resolve channel name from channels API
CHANNELS_RESPONSE=$(curl -s -H "Authorization: $API_TOKEN" \
  "https://api.clickup.com/api/v3/workspaces/$WORKSPACE_ID/chat/channels" 2>/dev/null || echo "")

if [ -n "$CHANNELS_RESPONSE" ]; then
  RESOLVED_NAME=$(echo "$CHANNELS_RESPONSE" | jq -r ".channels[] | select(.id == \"$CHANNEL_ID\") | .name" 2>/dev/null || echo "")
  if [ -n "$RESOLVED_NAME" ] && [ "$RESOLVED_NAME" != "null" ]; then
    CHANNEL_NAME="$RESOLVED_NAME"
  fi
fi

# Output results
echo "WORKSPACE_NAME=$WORKSPACE_NAME" > "$OUTPUT_FILE"
echo "CHANNEL_NAME=$CHANNEL_NAME" >> "$OUTPUT_FILE"
