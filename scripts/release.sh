#!/bin/bash
# Publish a build so SideStore on the phone sees it as an update.
#
#   1. Version is <VERSION file>.<commit count>, e.g. 0.1.14. Every release commit
#      bumps the count, so the number always moves forward with no state to keep.
#   2. make ipa with that version stamped in.
#   3. GitHub Release tagged v<version> carrying the IPA.
#   4. source.json gets the new version prepended, committed, and pushed. SideStore
#      polls that file and offers the update.
#
# DRY_RUN=1 does steps 1, 2 and the source.json edit locally, then reverts it.
set -euo pipefail
cd "$(dirname "$0")/.."

REPO="eshaan-mehta/everything-app"
APP="LifeTrack"
BRANCH="main"
DRY_RUN="${DRY_RUN:-0}"

if [ "$DRY_RUN" != "1" ]; then
  if [ -n "$(git status --porcelain)" ]; then
    echo "Uncommitted changes present. Commit first so the release matches the code." >&2
    exit 1
  fi
  if [ "$(git branch --show-current)" != "$BRANCH" ]; then
    echo "Release from $BRANCH." >&2
    exit 1
  fi
fi

COUNT=$(git rev-list --count HEAD)
VERSION="$(tr -d '[:space:]' < VERSION).$COUNT"
BUILD="$COUNT"
TAG="v$VERSION"

if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  echo "Tag $TAG already exists. Commit something before releasing again." >&2
  exit 1
fi

make ipa VERSION="$VERSION" BUILD="$BUILD"

IPA="build/$APP.ipa"
SIZE=$(stat -f%z "$IPA")
DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
URL="https://github.com/$REPO/releases/download/$TAG/$APP.ipa"

ENTRY=$(jq -n --arg v "$VERSION" --arg b "$BUILD" --arg d "$DATE" --arg u "$URL" --argjson s "$SIZE" \
  '{version: $v, buildVersion: $b, date: $d, downloadURL: $u, size: $s, minOSVersion: "26.0"}')
UPDATED=$(jq --argjson e "$ENTRY" '.apps[0].versions = ([$e] + .apps[0].versions)[:10]' source.json)

if [ "$DRY_RUN" = "1" ]; then
  echo "--- dry run: would create release $TAG with $IPA ($SIZE bytes) and prepend this to source.json:"
  echo "$ENTRY"
  exit 0
fi

printf '%s\n' "$UPDATED" > source.json

gh release create "$TAG" "$IPA" --repo "$REPO" --title "$APP $VERSION" --notes "Build $BUILD"
git add source.json
git commit -m "Release $VERSION"
git push origin "$BRANCH"
echo "Released $VERSION. SideStore will offer it as an update on its next refresh."
