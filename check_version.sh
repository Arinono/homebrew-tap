#!/usr/bin/env bash

set -eo pipefail

REPO="arinono/homebrew-tap"
GIT_AUTHOR_NAME="WTG Bot"
GIT_AUTHOR_EMAIL="homebrew-bot@withthegrid.com"

MODE="$1"
if [ -z "$MODE" ]; then
  echo "Usage: $0 <cask|formula> <cask-name> [assignee]"
  exit 1
fi

if [ "$MODE" != "cask" ] && [ "$MODE" != "formula" ]; then
  echo "Usage: $0 <cask|formula> <cask-name> [assignee]"
  exit 1
fi

CASK_NAME="$2"

if [ -z "$CASK_NAME" ]; then
  echo "Usage: $0 <cask-name>"
  exit 1
fi

CASK_FILE="Casks/$CASK_NAME.rb"
ASSIGNEE="$3"

if [ -z "$ASSIGNEE" ]; then
  ASSIGNEE="jdbruijn"
fi

UPSTREAM=$(curl -s https://formulae.brew.sh/api/$MODE/${CASK_NAME}.json)
UPSTREAM_VERSION=$(echo "$UPSTREAM" | jq -r '.version')
UPSTREAM_SHA256=$(echo "$UPSTREAM" | jq -r '.sha256')

LOCAL_VERSION=$(grep -E '^ *version' "$CASK_FILE" | cut -d'"' -f2)
LOCAL_SHA256=$(grep -E '^ *sha256' "$CASK_FILE" | cut -d'"' -f2)

if [[ "$UPSTREAM_VERSION" != "$LOCAL_VERSION" || "$UPSTREAM_SHA256" != "$LOCAL_SHA256" ]]; then
  echo "Version mismatch between upstream and local version:"
  echo "  Upstream: $UPSTREAM_VERSION $UPSTREAM_SHA256"
  echo "  Local:    $LOCAL_VERSION $LOCAL_SHA256"

  branch_name="chore-update-$CASK_NAME-$UPSTREAM_VERSION"
  git checkout -b "$branch_name"
  sed -i '' "s/^  version .*$/  version \"$UPSTREAM_VERSION\"/" "$CASK_FILE"
  sed -i '' "s/^  sha256 .*$/  sha256 \"$UPSTREAM_SHA256\"/" "$CASK_FILE"
  git add "$CASK_FILE"
  git commit --author="$GIT_AUTHOR_NAME <$GIT_AUTHOR_EMAIL>" \
    -m "chore: update $CASK_NAME to $UPSTREAM_VERSION"
  git push --set-upstream origin --atomic "$branch_name"
  gh pr create \
    --repo "$REPO" \
    --title "chore: update $CASK_NAME to $UPSTREAM_VERSION" \
    --body "Update $CASK_NAME from $LOCAL_VERSION to $UPSTREAM_VERSION" \
    --assignee "$ASSIGNEE" \
    --fill

  git checkout main
fi
