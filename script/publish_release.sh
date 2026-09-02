#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 VERSION [--dry-run]" >&2
  exit 2
}

[[ $# -ge 1 && $# -le 2 ]] || usage
VERSION="$1"
DRY_RUN=false
if [[ $# -eq 2 ]]; then
  [[ "$2" == "--dry-run" ]] || usage
  DRY_RUN=true
fi
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "VERSION must use major.minor.patch (for example 0.1.0)." >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="R3Dshot"
OWNER="r3d42-git"
REPOSITORY="$OWNER/$APP_NAME"
TAG="v$VERSION"
RELEASE_DIR="$ROOT_DIR/.release/$VERSION"
DMG_PATH="$RELEASE_DIR/$APP_NAME-$VERSION-mac-arm64.dmg"
CHECKSUM_PATH="$DMG_PATH.sha256"
NOTES_PATH="$ROOT_DIR/docs/releases/$VERSION.md"

for command in gh git mktemp shasum; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "Required command not found: $command" >&2
    exit 1
  }
done

if [[ "$(git -C "$ROOT_DIR" remote get-url origin)" != "https://github.com/$REPOSITORY.git" ]]; then
  echo "origin must be https://github.com/$REPOSITORY.git" >&2
  exit 1
fi
if [[ "$(gh api user --jq .login)" != "$OWNER" ]]; then
  echo "GitHub CLI is not authenticated as $OWNER." >&2
  exit 1
fi
if [[ ! -f "$DMG_PATH" || ! -f "$CHECKSUM_PATH" || ! -f "$NOTES_PATH" ]]; then
  echo "Expected artifact, checksum, or release notes are missing." >&2
  exit 1
fi
"$ROOT_DIR/script/verify_release.sh" "$VERSION" DMG "$DMG_PATH" "$CHECKSUM_PATH"

if ! git -C "$ROOT_DIR" rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  echo "Required annotated tag is missing: $TAG" >&2
  exit 1
fi
if [[ "$(git -C "$ROOT_DIR" rev-list -n 1 "$TAG")" != "$(git -C "$ROOT_DIR" rev-parse HEAD)" ]]; then
  echo "$TAG must resolve to the current release commit." >&2
  exit 1
fi
if ! git -C "$ROOT_DIR" ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null; then
  echo "$TAG is not pushed to origin." >&2
  exit 1
fi

if "$DRY_RUN"; then
  echo "Dry run passed: $TAG can be released to $REPOSITORY."
  exit 0
fi

if gh release view "$TAG" --repo "$REPOSITORY" >/dev/null 2>&1; then
  echo "GitHub Release $TAG already exists; refusing to alter it." >&2
  exit 1
fi

gh release create "$TAG" \
  "$DMG_PATH" \
  "$CHECKSUM_PATH" \
  --repo "$REPOSITORY" \
  --title "$APP_NAME $VERSION" \
  --notes-file "$NOTES_PATH"

REMOTE_DIGEST="$(gh api "/repos/$REPOSITORY/releases/tags/$TAG" --jq ".assets[] | select(.name == \"$(basename "$DMG_PATH")\") | .digest")"
LOCAL_DIGEST="sha256:$(shasum -a 256 "$DMG_PATH" | /usr/bin/awk '{ print $1 }')"
if [[ "$REMOTE_DIGEST" != "$LOCAL_DIGEST" ]]; then
  echo "GitHub-reported asset digest does not match the local DMG." >&2
  exit 1
fi

DOWNLOAD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/r3dshot-release-download.XXXXXX")"
cleanup() { rm -rf "$DOWNLOAD_DIR"; }
trap cleanup EXIT
gh release download "$TAG" \
  --repo "$REPOSITORY" \
  --dir "$DOWNLOAD_DIR" \
  --pattern "$(basename "$DMG_PATH")" \
  --pattern "$(basename "$CHECKSUM_PATH")"
"$ROOT_DIR/script/verify_release.sh" \
  "$VERSION" \
  DMG \
  "$DOWNLOAD_DIR/$(basename "$DMG_PATH")" \
  "$DOWNLOAD_DIR/$(basename "$CHECKSUM_PATH")"

gh release view "$TAG" --repo "$REPOSITORY" --json url --jq .url
