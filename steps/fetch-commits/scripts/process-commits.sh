#!/bin/bash
# Process and format commits

set -e

COMMITS_FILE="$1"
FULL_COMMIT_MESSAGE="$2"
OUTPUT_FILE="$3"
FILTER_AGENT_COMMITS="$4"
GROUP_BY_TYPE="$5"
SHOW_PR_LINKS="$6"

# Constants
CONVENTIONAL_COMMIT_TYPES="build|chore|docs|feat|fix|refactor|revert|style|test|release|security|deps|api"

# Helper function to format task links
format_task_links() {
  local message="$1"
  message=$(echo "$message" | sed -E "s/ctask \`([A-Za-z0-9\-]+)\`/[\1](https:\/\/app.clickup.com\/t\/${CLICKUP_WORKSPACE_ID}\/\1)/g")
  message=$(echo "$message" | sed -E "s/task \`([A-Za-z0-9\-]+)\`/[\1](https:\/\/app.clickup.com\/t\/\1)/g")
  echo "$message"
}

# Helper function to format conventional commits
format_conventional_commit() {
  local text="$1"
  local is_header="$2"

  # Check if text matches conventional commit pattern (case-insensitive)
  if echo "$text" | grep -Eiq "^(${CONVENTIONAL_COMMIT_TYPES})(\([^)]+\))?(!)?:"; then
    # Extract the prefix (case-insensitive)
    local prefix=$(echo "$text" | grep -oEi "^(${CONVENTIONAL_COMMIT_TYPES})(\([^)]+\))?(!)?:")
    local rest="${text#$prefix }"

    # Convert the commit type to lowercase, then capitalize first letter
    local type=$(echo "$prefix" | grep -oEi "^(${CONVENTIONAL_COMMIT_TYPES})" | tr '[:upper:]' '[:lower:]')
    type="$(tr '[:lower:]' '[:upper:]' <<< ${type:0:1})${type:1}"

    # Rebuild prefix with capitalized type
    local scope_and_breaking=$(echo "$prefix" | sed -E "s/^[^(:]*//" )
    local normalized_prefix="${type}${scope_and_breaking}"

    echo "**${normalized_prefix}** ${rest}"
  else
    echo "$text"
  fi
}

# Helper function to convert text to Title Case
title_case() {
  echo "$1" | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1'
}

# Helper function to extract name from Co-authored-by line
extract_coauthor_name() {
  local line="$1"
  local name
  name=$(echo "$line" | sed -E 's/^[[:space:]]*[Cc]o-authored-by:[[:space:]]*//')
  name=$(echo "$name" | sed -E 's/[[:space:]]*<[^>]+>[[:space:]]*$//')
  name=$(echo "$name" | sed -E 's/[[:space:]]+[0-9]+\+[^ ]+$//')
  name=$(echo "$name" | sed -E 's/[[:space:]]+[^ ]+@[^ ]+$//')
  echo "$name" | xargs
}

# Helper function to linkify PR references
linkify_pr_refs() {
  local message="$1"
  if [[ "$SHOW_PR_LINKS" == "true" ]]; then
    local repo_url="${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY}"
    message=$(echo "$message" | sed -E "s|#([0-9]{1,7})|[#\\1](${repo_url}/pull/\\1)|g")
  fi
  echo "$message"
}

COMMITS_JSON=$(cat "$COMMITS_FILE")

if [ "$COMMITS_JSON" = "[]" ] || [ -z "$COMMITS_JSON" ]; then
  echo "" > "$OUTPUT_FILE"
  exit 0
fi

COMMIT_COUNT=$(echo "$COMMITS_JSON" | jq 'length')

if [ "$COMMIT_COUNT" -eq 0 ]; then
  echo "" > "$OUTPUT_FILE"
  exit 0
fi

# Pre-scan: Find co-author info for copilot agent commits
COPILOT_COAUTHOR=""
for ((i=0; i<COMMIT_COUNT; i++)); do
  MESSAGE=$(echo "$COMMITS_JSON" | jq -r ".[$i].message")
  COAUTHOR_LINE=$(echo "$MESSAGE" | grep -i "Co-authored-by:" | head -1 || true)
  if [ -n "$COAUTHOR_LINE" ]; then
    EXTRACTED=$(extract_coauthor_name "$COAUTHOR_LINE")
    if [ -n "$EXTRACTED" ]; then
      COPILOT_COAUTHOR="$EXTRACTED"
      break
    fi
  fi
done

AUTHOR_LIST=()
AUTHOR_COMMITS_LIST=()
UNIQUE_KEYS=()
TYPE_LIST=()
TYPE_COMMITS_LIST=()

for ((i=0; i<COMMIT_COUNT; i++)); do
  RAW_AUTHOR=$(echo "$COMMITS_JSON" | jq -r ".[$i].author")
  AUTHOR=$(echo "$RAW_AUTHOR" | tr -c '[:alnum:] ' ' ' | tr -s ' ')
  AUTHOR=$(echo "$AUTHOR" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  [ -z "$AUTHOR" ] && AUTHOR="Unknown Contributor"

  RAW_MESSAGE=$(echo "$COMMITS_JSON" | jq -r ".[$i].message")
  FIRST_LINE=$(echo "$RAW_MESSAGE" | sed -n '1p')

  # Filter agent commits
  if [[ "$FILTER_AGENT_COMMITS" == "true" ]]; then
    if echo "$FIRST_LINE" | grep -qi "^Initial plan$"; then
      continue
    fi
    if echo "$FIRST_LINE" | grep -qi "^Agent-Logs-Url:"; then
      continue
    fi
    if echo "$FIRST_LINE" | grep -qi "^Co-authored-by:"; then
      continue
    fi
  fi

  # Capitalize author name (Title Case)
  AUTHOR=$(title_case "$AUTHOR")

  # Handle copilot agent bot author
  AUTHOR_LOWER=$(echo "$RAW_AUTHOR" | tr '[:upper:]' '[:lower:]')
  if [[ "$AUTHOR_LOWER" == *"copilot"*"agent"*"bot"* ]] || [[ "$AUTHOR_LOWER" == *"copilot-swe-agent"* ]]; then
    if [ -n "$COPILOT_COAUTHOR" ]; then
      COAUTHOR_DISPLAY=$(title_case "$COPILOT_COAUTHOR")
      AUTHOR="${COAUTHOR_DISPLAY} (Copilot Agent)"
    else
      AUTHOR="Copilot Agent"
    fi
  fi

  AUTHOR=$(printf '%s' "$AUTHOR")
  if [[ "$FULL_COMMIT_MESSAGE" == "true" ]]; then
    FORMATTED_MESSAGE=$(format_task_links "$RAW_MESSAGE")

    HEADER_LINE=$(echo "$FORMATTED_MESSAGE" | sed -n '1p')
    BODY_LINES=$(echo "$FORMATTED_MESSAGE" | sed '1d')

    # Strip Co-authored-by lines from body when filtering
    if [[ "$FILTER_AGENT_COMMITS" == "true" ]]; then
      BODY_LINES=$(echo "$BODY_LINES" | grep -vi "^[[:space:]]*Co-authored-by:" || true)
    fi

    HEADER_LINE=$(format_conventional_commit "$HEADER_LINE" "true")
    HEADER_LINE=$(linkify_pr_refs "$HEADER_LINE")

    # Consistent formatting: always use single space after bullet
    FINAL_COMMIT_BLOCK="* ${HEADER_LINE}"

    # Only add body if it exists and has non-whitespace content
    if [ -n "$BODY_LINES" ] && [ -n "$(echo "$BODY_LINES" | tr -d '[:space:]')" ]; then
      if echo "$BODY_LINES" | grep -qE '^\s*[\*\-\+]'; then
        INDENTED_BODY=$(echo "$BODY_LINES" | sed -E 's/^\s*([\*\-\+])/  \1 /')
      else
        INDENTED_BODY=$(echo "$BODY_LINES" | sed 's/^/  /')
      fi
      INDENTED_BODY=$(linkify_pr_refs "$INDENTED_BODY")
      FINAL_COMMIT_BLOCK="${FINAL_COMMIT_BLOCK}"$'\n\n'"${INDENTED_BODY}"
    fi

  else
    MESSAGE=$(echo "$COMMITS_JSON" | jq -r ".[$i].message" | sed -n '1p')
    MESSAGE=$(format_task_links "$MESSAGE")
    MESSAGE=$(format_conventional_commit "$MESSAGE" "false")
    MESSAGE=$(linkify_pr_refs "$MESSAGE")

    FINAL_COMMIT_BLOCK="* ${MESSAGE}"
  fi

  # Use only the commit message for uniqueness, not author+message
  COMMIT_SIGNATURE=$(echo "$FINAL_COMMIT_BLOCK" | sed 's/^\*[[:space:]]*//')

  # Skip merge commits (both "Merge branch" and "Merge pull request")
  if [[ ! "$FINAL_COMMIT_BLOCK" =~ ^\*[[:space:]]+[Mm]erge[[:space:]]+(branch|pull[[:space:]]+request) ]]; then
    IS_UNIQUE=true
    for existing_key in "${UNIQUE_KEYS[@]}"; do
      if [[ "$existing_key" == "$COMMIT_SIGNATURE" ]]; then
        IS_UNIQUE=false
        break
      fi
    done

    if $IS_UNIQUE; then
      UNIQUE_KEYS+=("$COMMIT_SIGNATURE")

      if [[ "$GROUP_BY_TYPE" == "true" ]]; then
        # Determine conventional commit type
        COMMIT_TYPE="Other"
        if echo "$FIRST_LINE" | grep -Eiq "^(${CONVENTIONAL_COMMIT_TYPES})(\([^)]+\))?(!)?:"; then
          COMMIT_TYPE=$(echo "$FIRST_LINE" | grep -oEi "^(${CONVENTIONAL_COMMIT_TYPES})" | tr '[:upper:]' '[:lower:]')
          COMMIT_TYPE="$(tr '[:lower:]' '[:upper:]' <<< ${COMMIT_TYPE:0:1})${COMMIT_TYPE:1}"
        fi

        # Map types to display labels with emojis
        case "$COMMIT_TYPE" in
          Feat) TYPE_LABEL="🎯 Features" ;;
          Fix) TYPE_LABEL="🔧 Fixes" ;;
          Refactor) TYPE_LABEL="🔄 Refactors" ;;
          Docs) TYPE_LABEL="📝 Documentation" ;;
          Style) TYPE_LABEL="🎨 Styles" ;;
          Test) TYPE_LABEL="🧪 Tests" ;;
          Build) TYPE_LABEL="🏗️ Build" ;;
          Chore) TYPE_LABEL="🧹 Chores" ;;
          Revert) TYPE_LABEL="⏪ Reverts" ;;
          Security) TYPE_LABEL="🔒 Security" ;;
          Deps) TYPE_LABEL="📦 Dependencies" ;;
          Api) TYPE_LABEL="🔌 API" ;;
          Release) TYPE_LABEL="🚀 Releases" ;;
          *) TYPE_LABEL="📋 Other" ;;
        esac

        # Strip conventional commit prefix for cleaner display under type headers
        CLEAN_BLOCK="$FINAL_COMMIT_BLOCK"
        if [[ "$COMMIT_TYPE" != "Other" ]]; then
          CLEAN_BLOCK=$(echo "$FINAL_COMMIT_BLOCK" | sed -E "s/^\* \*\*[^*]+\*\* /\* /")
        fi

        FOUND=false
        for j in "${!TYPE_LIST[@]}"; do
          if [[ "${TYPE_LIST[$j]}" == "$TYPE_LABEL" ]]; then
            TYPE_COMMITS_LIST[$j]+="${CLEAN_BLOCK}"$'\n\n'
            FOUND=true
            break
          fi
        done

        if ! $FOUND; then
          TYPE_LIST+=("$TYPE_LABEL")
          TYPE_COMMITS_LIST+=("${CLEAN_BLOCK}"$'\n\n')
        fi
      else
        # Group by author (default)
        FOUND=false
        for j in "${!AUTHOR_LIST[@]}"; do
          if [[ "${AUTHOR_LIST[$j]}" == "$AUTHOR" ]]; then
            AUTHOR_COMMITS_LIST[$j]+="${FINAL_COMMIT_BLOCK}"$'\n\n'
            FOUND=true
            break
          fi
        done

        if ! $FOUND; then
          AUTHOR_LIST+=("$AUTHOR")
          AUTHOR_COMMITS_LIST+=("${FINAL_COMMIT_BLOCK}"$'\n\n')
        fi
      fi
    fi
  fi
done

# Build changelog
COMMIT_LIST_MD=""
if [[ "$GROUP_BY_TYPE" == "true" ]]; then
  for k in "${!TYPE_LIST[@]}"; do
    TYPE="${TYPE_LIST[$k]}"
    COMMITS="${TYPE_COMMITS_LIST[$k]}"
    if [ -n "$COMMITS" ]; then
      COMMIT_LIST_MD+=$'\n'"_*${TYPE}:*_\n$COMMITS"
    fi
  done
else
  for k in "${!AUTHOR_LIST[@]}"; do
    AUTHOR="${AUTHOR_LIST[$k]}"
    COMMITS="${AUTHOR_COMMITS_LIST[$k]}"
    if [ -n "$COMMITS" ]; then
      COMMIT_LIST_MD+=$'\n'"_*$AUTHOR:*_\n$COMMITS"
    fi
  done
fi

echo "$COMMIT_LIST_MD" > "$OUTPUT_FILE"
