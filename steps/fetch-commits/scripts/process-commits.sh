#!/bin/bash
# Process and format commits

set -e

COMMITS_FILE="$1"
FULL_COMMIT_MESSAGE="$2"
SORT_ALPHABETICALLY="$3"
OUTPUT_FILE="$4"

# Constants
CONVENTIONAL_COMMIT_TYPES="build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test|release|security|deps|config|hotfix|ui|api"

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

  if echo "$text" | grep -Eq "^(${CONVENTIONAL_COMMIT_TYPES})(\([^)]+\))?(!)?:"; then
    local prefix=$(echo "$text" | grep -oE "^(${CONVENTIONAL_COMMIT_TYPES})(\([^)]+\))?(!)?:")
    local rest="${text#$prefix }"
    echo "**${prefix}** ${rest}"
  else
    echo "$text"
  fi
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

AUTHOR_LIST=()
AUTHOR_COMMITS_LIST=()
UNIQUE_KEYS=()

for ((i=0; i<COMMIT_COUNT; i++)); do
  RAW_AUTHOR=$(echo "$COMMITS_JSON" | jq -r ".[$i].author")
  AUTHOR=$(echo "$RAW_AUTHOR" | tr -c '[:alnum:] ' ' ' | tr -s ' ')
  AUTHOR=$(echo "$AUTHOR" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  [ -z "$AUTHOR" ] && AUTHOR="Unknown Contributor"

  AUTHOR=$(printf '%s' "$AUTHOR")
  if [[ "$FULL_COMMIT_MESSAGE" == "true" ]]; then
    RAW_MESSAGE=$(echo "$COMMITS_JSON" | jq -r ".[$i].message")
    FORMATTED_MESSAGE=$(format_task_links "$RAW_MESSAGE")

    HEADER_LINE=$(echo "$FORMATTED_MESSAGE" | sed -n '1p')
    BODY_LINES=$(echo "$FORMATTED_MESSAGE" | sed '1d')

    HEADER_LINE=$(format_conventional_commit "$HEADER_LINE" "true")

    # Consistent formatting: always use single space after bullet
    FINAL_COMMIT_BLOCK="* ${HEADER_LINE}"

    # Only add body if it exists and is not empty
    if [ -n "$BODY_LINES" ] && [ "$BODY_LINES" != "" ]; then
      if echo "$BODY_LINES" | grep -qE '^\s*[\*\-\+]'; then
        INDENTED_BODY=$(echo "$BODY_LINES" | sed -E 's/^\s*([\*\-\+])/  \1 /')
      else
        INDENTED_BODY=$(echo "$BODY_LINES" | sed 's/^/  /')
      fi
      FINAL_COMMIT_BLOCK="${FINAL_COMMIT_BLOCK}"$'\n\n'"${INDENTED_BODY}"
    fi

  else
    MESSAGE=$(echo "$COMMITS_JSON" | jq -r ".[$i].message" | sed -n '1p')
    MESSAGE=$(format_task_links "$MESSAGE")
    MESSAGE=$(format_conventional_commit "$MESSAGE" "false")

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
done

# Build changelog
COMMIT_LIST_MD=""
for k in "${!AUTHOR_LIST[@]}"; do
  AUTHOR="${AUTHOR_LIST[$k]}"
  COMMITS="${AUTHOR_COMMITS_LIST[$k]}"
  if [ -n "$COMMITS" ]; then
    if [[ "$SORT_ALPHABETICALLY" == "true" ]]; then
      # Custom sort that preserves multi-line commit blocks
      TEMP_FILE=$(mktemp)
      echo "$COMMITS" > "$TEMP_FILE"

      # Split commits by double newlines, sort by first line, then rejoin
      awk 'BEGIN{RS="\n\n"; ORS="\n\n"} {commits[NR] = $0; titles[NR] = $1} END{
        n = asort(titles, sorted_titles)
        for(i=1; i<=n; i++) {
          for(j=1; j<=NR; j++) {
            if(titles[j] == sorted_titles[i]) {
              print commits[j]
              delete commits[j]
              delete titles[j]
              break
            }
          }
        }
      }' "$TEMP_FILE" | sed '$s/\n\n$/\n/' > "${TEMP_FILE}.sorted"

      SORTED_COMMITS=$(cat "${TEMP_FILE}.sorted")
      rm -f "$TEMP_FILE" "${TEMP_FILE}.sorted"

      COMMIT_LIST_MD+=$'\n'"_*$AUTHOR:*_\n$SORTED_COMMITS"
    else
      COMMIT_LIST_MD+=$'\n'"_*$AUTHOR:*_\n$COMMITS"
    fi
  fi
done

echo "$COMMIT_LIST_MD" > "$OUTPUT_FILE"
