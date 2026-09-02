#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 4 ]]; then
  echo "usage: $0 VERSION DMG [PATH_TO_DMG] [PATH_TO_CHECKSUM]" >&2
  exit 2
fi

VERSION="$1"
FORMAT="$2"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="R3Dshot"
BUNDLE_ID="org.r3d.R3Dshot"
TEAM_ID="${R3DSHOT_TEAM_ID:-G6JH37W285}"
EXPECTED_DMG_NAME="$APP_NAME-$VERSION-mac-arm64.dmg"
DEFAULT_RELEASE_DIR="$ROOT_DIR/.release/$VERSION"
DMG_PATH="${3:-$DEFAULT_RELEASE_DIR/$EXPECTED_DMG_NAME}"
CHECKSUM_PATH="${4:-$DMG_PATH.sha256}"
MOUNT_POINT=""

if [[ "$FORMAT" != "DMG" ]]; then
  echo "Unsupported release format: $FORMAT" >&2
  exit 2
fi
if [[ ! -f "$DMG_PATH" || ! -f "$CHECKSUM_PATH" ]]; then
  echo "Expected DMG and checksum were not found." >&2
  exit 1
fi
if [[ "$(basename "$DMG_PATH")" != "$EXPECTED_DMG_NAME" ]]; then
  echo "Unexpected artifact name: $(basename "$DMG_PATH")" >&2
  exit 1
fi

cleanup() {
  if [[ -n "$MOUNT_POINT" && -d "$MOUNT_POINT" ]]; then
    hdiutil detach "$MOUNT_POINT" -quiet || true
  fi
}
trap cleanup EXIT

expected_sha256="$(/usr/bin/awk 'NR == 1 { print $1 }' "$CHECKSUM_PATH")"
actual_sha256="$(shasum -a 256 "$DMG_PATH" | /usr/bin/awk '{ print $1 }')"
if [[ ! "$expected_sha256" =~ ^[A-Fa-f0-9]{64}$ || "$actual_sha256" != "$expected_sha256" ]]; then
  echo "DMG SHA-256 does not match $CHECKSUM_PATH." >&2
  exit 1
fi

codesign --verify --verbose=2 "$DMG_PATH"
hdiutil verify "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG_PATH"

MOUNT_POINT="$(hdiutil attach "$DMG_PATH" -readonly -noverify -nobrowse | /usr/bin/awk '/\/Volumes\// { print substr($0, index($0, "/Volumes/")); exit }')"
APP_BUNDLE="$MOUNT_POINT/$APP_NAME.app"
if [[ -z "$MOUNT_POINT" || ! -d "$APP_BUNDLE" ]]; then
  echo "The mounted DMG did not contain $APP_NAME.app." >&2
  exit 1
fi
if [[ ! -L "$MOUNT_POINT/Applications" || ! -f "$MOUNT_POINT/LICENSE.txt" || ! -f "$MOUNT_POINT/INSTALL R3DSHOT.txt" ]]; then
  echo "The mounted DMG is missing its Applications alias, license, or install instructions." >&2
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
xcrun stapler validate "$APP_BUNDLE"
spctl --assess --type execute --verbose=4 "$APP_BUNDLE"

app_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_BUNDLE/Contents/Info.plist")"
app_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_BUNDLE/Contents/Info.plist")"
app_architectures="$(lipo -archs "$APP_BUNDLE/Contents/MacOS/$APP_NAME")"
app_signing_info="$(codesign -dvv --verbose=4 "$APP_BUNDLE" 2>&1)"
if [[ "$app_bundle_id" != "$BUNDLE_ID" || "$app_version" != "$VERSION" || "$app_architectures" != "arm64" ]]; then
  echo "The contained app does not match its expected bundle metadata or arm64 architecture." >&2
  exit 1
fi
if ! rg -qF "TeamIdentifier=$TEAM_ID" <<< "$app_signing_info" \
  || ! rg -q 'flags=.*runtime' <<< "$app_signing_info"; then
  echo "The contained app does not satisfy the team or Hardened Runtime contract." >&2
  exit 1
fi

echo "Verified $DMG_PATH"
echo "SHA-256: $actual_sha256"
echo "Bundle ID: $app_bundle_id"
echo "Architectures: $app_architectures"
