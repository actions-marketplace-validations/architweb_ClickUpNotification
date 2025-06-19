#!/bin/bash
# Process and format commits

set -e

COMMITS_FILE="$1"
FULL_COMMIT_MESSAGE="$2"
SORT_ALPHABETICALLY="$3"
OUTPUT_FILE="$4"

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

  # Ensure AUTHOR is properly quoted to prevent command execution
  AUTHOR=$(printf '%s' "$AUTHOR")

  if [[ "$FULL_COMMIT_MESSAGE" == "true" ]]; then
    RAW_MESSAGE=$(echo "$COMMITS_JSON" | jq -r ".[$i].message")

    FORMATTED_MESSAGE=$(echo "$RAW_MESSAGE" | sed -E "s/ctask \`([A-Za-z0-9\-]+)\`/[\`\1\`](https:\/\/app.clickup.com\/t\/${CLICKUP_WORKSPACE_ID}\/\1)/g")
    FORMATTED_MESSAGE=$(echo "$FORMATTED_MESSAGE" | sed -E "s/task \`([0-9a-z]+)\`/[\`\1\`](https:\/\/app.clickup.com\/t\/\1)/g")

    HEADER_LINE=$(echo "$FORMATTED_MESSAGE" | sed -n '1p')
    BODY_LINES=$(echo "$FORMATTED_MESSAGE" | sed '1d')

    if echo "$HEADER_LINE" | grep -Eq '^(build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test)(\([^)]+\))?(!)?:'; then
      HEADER_LINE="**${HEADER_LINE}**"
    fi

    if echo "$BODY_LINES" | grep -qE '^\s*[\*\-\+]'; then
      INDENTED_BODY=$(echo "$BODY_LINES" | sed -E 's/^\s*([\*\-\+])/    \1   /')
    else
      INDENTED_BODY=$(echo "$BODY_LINES" | sed 's/^/    /')
    fi

    FINAL_COMMIT_BLOCK="*   ${HEADER_LINE}"
    [ -n "$BODY_LINES" ] && FINAL_COMMIT_BLOCK="${FINAL_COMMIT_BLOCK}"$'\n'"${INDENTED_BODY}"

  else
    MESSAGE=$(echo "$COMMITS_JSON" | jq -r ".[$i].message" | sed -n '1p')

    MESSAGE=$(echo "$MESSAGE" | sed -E "s/ctask \`([A-Za-z0-9\-]+)\`/[\`\1\`](https:\/\/app.clickup.com\/t\/${CLICKUP_WORKSPACE_ID}\/\1)/g")
    MESSAGE=$(echo "$MESSAGE" | sed -E "s/task \`([0-9a-z]+)\`/[\`\1\`](https:\/\/app.clickup.com\/t\/\1)/g")

    if echo "$MESSAGE" | grep -qE '^((build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test)(\([^)]+\))?(!)?:)'; then
      PREFIX=$(echo "$MESSAGE" | grep -oE '^((build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test)(\([^)]+\))?(!)?:)')
      REST="${MESSAGE#$PREFIX }"
      MESSAGE="**${PREFIX}** ${REST}"
    fi

    FINAL_COMMIT_BLOCK="* ${MESSAGE}"
  fi

  KEY="${AUTHOR}::${FINAL_COMMIT_BLOCK}"

  # Skip merge commits
  if [[ ! "$FINAL_COMMIT_BLOCK" =~ ^\*[[:space:]]+[Mm]erge[[:space:]]+branch ]]; then
    IS_UNIQUE=true
    for existing_key in "${UNIQUE_KEYS[@]}"; do
      if [[ "$existing_key" == "$KEY" ]]; then
        IS_UNIQUE=false
        break
      fi
    done

    if $IS_UNIQUE; then
      UNIQUE_KEYS+=("$KEY")

      FOUND=false
      for j in "${!AUTHOR_LIST[@]}"; do
        if [[ "${AUTHOR_LIST[$j]}" == "$AUTHOR" ]]; then
          AUTHOR_COMMITS_LIST[$j]+="${FINAL_COMMIT_BLOCK}"$'\n'
          FOUND=true
          break
        fi
      done

      if ! $FOUND; then
        AUTHOR_LIST+=("$AUTHOR")
        AUTHOR_COMMITS_LIST+=("${FINAL_COMMIT_BLOCK}"$'\n')
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
      SORTED_COMMITS=$(echo "$COMMITS" | sort)
      COMMIT_LIST_MD+=$'\n'"_*$AUTHOR:*_\n$SORTED_COMMITS"
    else
      COMMIT_LIST_MD+=$'\n'"_*$AUTHOR:*_\n$COMMITS"
    fi
  fi
done

echo "$COMMIT_LIST_MD" > "$OUTPUT_FILE"
