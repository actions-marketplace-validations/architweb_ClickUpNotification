#!/bin/bash
# Generate commit statistics

set -e

COMMITS_FILE="$1"
META_FILE="$2"
OUTPUT_FILE="$3"

# Early exit if no commits file or empty
if [ ! -f "$COMMITS_FILE" ]; then
  echo "" > "$OUTPUT_FILE"
  exit 0
fi

COMMITS_JSON=$(cat "$COMMITS_FILE")

# Early exit if no commits or no metadata
if [ "$COMMITS_JSON" = "[]" ] || [ -z "$COMMITS_JSON" ] || [ ! -f "$META_FILE" ]; then
  echo "" > "$OUTPUT_FILE"
  exit 0
fi

# Read metadata - exit early if missing required data
if ! source "$META_FILE" 2>/dev/null; then
  echo "" > "$OUTPUT_FILE"
  exit 0
fi

# Calculate statistics
TOTAL_COMMITS=$(echo "$COMMITS_JSON" | jq 'length')
UNIQUE_AUTHORS=$(echo "$COMMITS_JSON" | jq -r '.[].author' | sort -u | wc -l)

# Get file and line statistics using single git diff call
if [ -n "$PREVIOUS_SHA" ] && [ "$PREVIOUS_SHA" != "$CURRENT_SHA" ]; then
  # Get diff stats and name status separately for reliability
  DIFF_STATS=$(git diff --stat "$PREVIOUS_SHA...$CURRENT_SHA" 2>/dev/null || echo "")
  NAME_STATUS=$(git diff --name-status "$PREVIOUS_SHA...$CURRENT_SHA" 2>/dev/null || echo "")

  if [ -n "$DIFF_STATS" ]; then
    FILES_CHANGED=$(echo "$DIFF_STATS" | tail -1 | grep -oE '[0-9]+ files? changed' | grep -oE '[0-9]+' || echo "0")
    LINES_ADDED=$(echo "$DIFF_STATS" | tail -1 | grep -oE '[0-9]+ insertions?' | grep -oE '[0-9]+' || echo "0")
    LINES_REMOVED=$(echo "$DIFF_STATS" | tail -1 | grep -oE '[0-9]+ deletions?' | grep -oE '[0-9]+' || echo "0")
  else
    FILES_CHANGED="0"
    LINES_ADDED="0"
    LINES_REMOVED="0"
  fi

  if [ -n "$NAME_STATUS" ]; then
    FILES_ADDED=$(echo "$NAME_STATUS" | grep -c '^A' || echo "0")
    FILES_REMOVED=$(echo "$NAME_STATUS" | grep -c '^D' || echo "0")
  else
    FILES_ADDED="0"
    FILES_REMOVED="0"
  fi
else
  FILES_CHANGED="0"
  LINES_ADDED="0"
  LINES_REMOVED="0"
  FILES_ADDED="0"
  FILES_REMOVED="0"
fi

# Calculate commit type statistics
REFACTOR_COMMITS=$(echo "$COMMITS_JSON" | jq -r '.[].message' | grep -iEc '^(refactor|refact)(\([^)]*\))?:' || echo "0")
FIX_COMMITS=$(echo "$COMMITS_JSON" | jq -r '.[].message' | grep -iEc '^fix(\([^)]*\))?:' || echo "0")

# Determine release type based on commit messages
FEAT_COMMITS=$(echo "$COMMITS_JSON" | jq -r '.[].message' | grep -iEc '^feat(\([^)]*\))?:' || echo "0")
BREAKING_COMMITS=$(echo "$COMMITS_JSON" | jq -r '.[].message' | grep -iEc '^[^:]+(\([^)]*\))?!:' || echo "0")

if [ "$BREAKING_COMMITS" -gt 0 ]; then
  RELEASE_TYPE="🚨 Major"
elif [ "$FEAT_COMMITS" -gt 0 ]; then
  RELEASE_TYPE="🎯 Minor"
elif [ "$FIX_COMMITS" -gt 0 ]; then
  RELEASE_TYPE="🔧 Patch"
else
  RELEASE_TYPE="📝 Other"
fi

# Find top contributor
TOP_CONTRIBUTOR=$(echo "$COMMITS_JSON" | jq -r '.[].author' | sort | uniq -c | sort -nr | head -1 | sed 's/^[[:space:]]*[0-9]*[[:space:]]*//' || echo "Unknown")

# Calculate time since last deployment
if [ -n "$PREVIOUS_SHA" ]; then
  PREVIOUS_COMMIT_DATE=$(git show -s --format=%ct "$PREVIOUS_SHA" 2>/dev/null || echo "")
  CURRENT_COMMIT_DATE=$(git show -s --format=%ct "$CURRENT_SHA" 2>/dev/null || echo "")

  if [ -n "$PREVIOUS_COMMIT_DATE" ] && [ -n "$CURRENT_COMMIT_DATE" ]; then
    TIME_DIFF=$((CURRENT_COMMIT_DATE - PREVIOUS_COMMIT_DATE))
    DAYS=$((TIME_DIFF / 86400))
    HOURS=$(((TIME_DIFF % 86400) / 3600))
    MINUTES=$(((TIME_DIFF % 3600) / 60))

    TIME_SINCE="${DAYS} day(s), ${HOURS} hour(s), ${MINUTES} minute(s)"
  else
    TIME_SINCE="0 day(s), 0 hour(s), 0 minute(s)"
  fi
else
  TIME_SINCE="first deployment"
fi

# Build statistics
STATS_TABLE="\n\n\n📊 **Stats:**\n"
STATS_TABLE+="📝 **Count**: ${TOTAL_COMMITS} Commit(s)\n"
STATS_TABLE+="🎯 **Release Type**: ${RELEASE_TYPE}\n"
STATS_TABLE+="📁 **Changed**: ${FILES_CHANGED} file(s)\n"
STATS_TABLE+="➕ **Added**: +${FILES_ADDED} file(s), +${LINES_ADDED} line(s)\n"
STATS_TABLE+="➖ **Removed**: -${FILES_REMOVED} file(s), -${LINES_REMOVED} line(s)\n"
STATS_TABLE+="🔧 **Fix(es)**: ${FIX_COMMITS} commit(s)\n"
STATS_TABLE+="🔄 **Refactor(s)**: ${REFACTOR_COMMITS} commit(s)\n"
STATS_TABLE+="⏰ **Last Deploy**: ${TIME_SINCE}\n"
STATS_TABLE+="👥 **Contributor(s)**: ${UNIQUE_AUTHORS}\n"
STATS_TABLE+="🏆 **Top Contributor**: ${TOP_CONTRIBUTOR}"

echo -e "$STATS_TABLE" > "$OUTPUT_FILE"
