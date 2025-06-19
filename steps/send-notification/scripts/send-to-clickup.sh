#!/bin/bash
# Send message to ClickUp API

set -e

MESSAGE_FILE="$1"
API_TOKEN="$2"
WORKSPACE_ID="$3"
CHANNEL_ID="$4"

# Create JSON payload
PAYLOAD_FILE=$(mktemp)
jq -n --arg content "$(cat "$MESSAGE_FILE")" '{
  type: "message",
  content_format: "text/md",
  content: $content
}' > "$PAYLOAD_FILE"

# Send to ClickUp
RESPONSE_FILE=$(mktemp)
HTTP_CODE=$(curl -s -o "$RESPONSE_FILE" -w "%{http_code}" \
  -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: $API_TOKEN" \
  -d @"$PAYLOAD_FILE" \
  "https://api.clickup.com/api/v3/workspaces/$WORKSPACE_ID/chat/channels/$CHANNEL_ID/messages")

# Cleanup
rm -f "$PAYLOAD_FILE" "$RESPONSE_FILE"

# Check result
if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
  echo "--- ClickUp notification sent successfully ---"
  exit 0
else
  echo "::error::Failed to send notification to ClickUp. HTTP code: $HTTP_CODE"
  exit 1
fi
