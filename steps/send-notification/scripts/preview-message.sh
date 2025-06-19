#!/bin/bash
# Handle test mode preview

set -e

MESSAGE_FILE="$1"
NAMES_FILE="$2"
WORKSPACE_ID="$3"
CHANNEL_ID="$4"

# Load resolved names
if [ -f "$NAMES_FILE" ]; then
  source "$NAMES_FILE"
fi

# Set defaults if not loaded
WORKSPACE_NAME="${WORKSPACE_NAME:-$WORKSPACE_ID}"
CHANNEL_NAME="${CHANNEL_NAME:-$CHANNEL_ID}"

echo "🧪 TEST MODE ENABLED - Message preview (NOT SENT to ClickUp)"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "📋 PREVIEW OF MESSAGE CONTENT:"
echo "═══════════════════════════════════════════════════════════════"
echo ""
cat "$MESSAGE_FILE"
echo ""

MESSAGE_LENGTH=$(cat "$MESSAGE_FILE" | wc -c)

echo "═══════════════════════════════════════════════════════════════"
echo "📝 MESSAGE DETAILS:"
echo "═══════════════════════════════════════════════════════════════"

# Build destination string intelligently
DESTINATION="ClickUp"

# Add workspace info
if [ -n "$WORKSPACE_NAME" ] && [ "$WORKSPACE_NAME" != "***" ]; then
  DESTINATION="$DESTINATION => $WORKSPACE_NAME"
fi

# Add channel info
DESTINATION="$DESTINATION => Channels"
if [ -n "$CHANNEL_NAME" ] && [ "$CHANNEL_NAME" != "***" ]; then
  DESTINATION="$DESTINATION => $CHANNEL_NAME"
fi

echo "• Destination: $DESTINATION"
echo "• Content Format: text/md"
echo "• Character Count: $MESSAGE_LENGTH characters"
echo "• API Token: Provided (hidden for security)"
echo ""
echo "⚠️  TEST MODE: No actual API call made to ClickUp"
echo "    Set test_mode to \"false\" to send this message"
echo "═══════════════════════════════════════════════════════════════"
