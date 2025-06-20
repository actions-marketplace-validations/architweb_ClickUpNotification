#!/bin/bash
# Generate commit statistics

set -e

COMMITS_FILE="$1"
META_FILE="$2"
OUTPUT_FILE="$3"

COMMITS_JSON=$(cat "$COMMITS_FILE")

if [ "$COMMITS_JSON" = "[]" ] || [ -z "$COMMITS_JSON" ] || [ ! -f "$META_FILE" ]; then
  echo "" > "$OUTPUT_FILE"
  exit 0
fi

# Read metadata
source "$META_FILE"

# Calculate statistics
TOTAL_COMMITS=$(echo "$COMMITS_JSON" | jq 'length')
UNIQUE_AUTHORS=$(echo "$COMMITS_JSON" | jq -r '.[].author' | sort -u | wc -l)

# Get file and line statistics using git diff
if [ -n "$PREVIOUS_SHA" ] && [ "$PREVIOUS_SHA" != "$CURRENT_SHA" ]; then
  DIFF_STATS=$(git diff --stat "$PREVIOUS_SHA...$CURRENT_SHA" 2>/dev/null || echo "")
  if [ -n "$DIFF_STATS" ]; then
    FILES_CHANGED=$(echo "$DIFF_STATS" | tail -1 | grep -oE '[0-9]+ files? changed' | grep -oE '[0-9]+' || echo "0")
    LINES_ADDED=$(echo "$DIFF_STATS" | tail -1 | grep -oE '[0-9]+ insertions?' | grep -oE '[0-9]+' || echo "0")
    LINES_REMOVED=$(echo "$DIFF_STATS" | tail -1 | grep -oE '[0-9]+ deletions?' | grep -oE '[0-9]+' || echo "0")
  else
    FILES_CHANGED="0"
    LINES_ADDED="0"
    LINES_REMOVED="0"
  fi
else
  FILES_CHANGED="0"
  LINES_ADDED="0"
  LINES_REMOVED="0"
fi

# Calculate time since last deployment
if [ -n "$PREVIOUS_SHA" ]; then
  PREVIOUS_COMMIT_DATE=$(git show -s --format=%ct "$PREVIOUS_SHA" 2>/dev/null || echo "")
  CURRENT_COMMIT_DATE=$(git show -s --format=%ct "$CURRENT_SHA" 2>/dev/null || echo "")

  if [ -n "$PREVIOUS_COMMIT_DATE" ] && [ -n "$CURRENT_COMMIT_DATE" ]; then
    TIME_DIFF=$((CURRENT_COMMIT_DATE - PREVIOUS_COMMIT_DATE))
    DAYS=$((TIME_DIFF / 86400))
    HOURS=$(((TIME_DIFF % 86400) / 3600))

    if [ "$DAYS" -gt 0 ]; then
      if [ "$HOURS" -gt 0 ]; then
        TIME_SINCE="${DAYS} days, ${HOURS}h ago"
      else
        TIME_SINCE="${DAYS} days ago"
      fi
    elif [ "$HOURS" -gt 0 ]; then
      TIME_SINCE="${HOURS}h ago"
    else
      MINUTES=$((TIME_DIFF / 60))
      TIME_SINCE="${MINUTES}m ago"
    fi
  else
    TIME_SINCE="unknown"
  fi
else
  TIME_SINCE="first deployment"
fi

# Build statistics table
STATS_TABLE="\n\n📊 **Stats:**\n"
STATS_TABLE+="| Count        | $TOTAL_COMMITS Commits |\n"
STATS_TABLE+="| Changed      | $FILES_CHANGED files   |\n"
STATS_TABLE+="| Added        | +$LINES_ADDED lines    |\n"
STATS_TABLE+="| Removed      | +$LINES_REMOVED lines  |\n"
STATS_TABLE+="| Last Deploy  | $TIME_SINCE            |\n"
STATS_TABLE+="| Contributors | $UNIQUE_AUTHORS        |\n"

echo "$STATS_TABLE" > "$OUTPUT_FILE"
