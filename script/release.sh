#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 VERSION" >&2
  exit 2
fi

VERSION="$1"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "VERSION must use major.minor.patch (for example 0.1.0)." >&2
  exit 2
fi

APP_NAME="R3Dshot"
BUNDLE_ID="org.r3d.R3Dshot"
TEAM_ID="${R3DSHOT_TEAM_ID:-G6JH37W285}"
SIGNING_IDENTITY="${R3DSHOT_SIGNING_IDENTITY:-Developer ID Application: Philipp John Hild (G6JH37W285)}"
NOTARY_PROFILE="${R3DSHOT_NOTARY_PROFILE:-R3Dshot}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RELEASE_DIR="$ROOT_DIR/.release/$VERSION"
ARCHIVE_PATH="$RELEASE_DIR/$APP_NAME.xcarchive"
APP_BUNDLE="$ARCHIVE_PATH/Products/Applications/$APP_NAME.app"
DMG_NAME="$APP_NAME-$VERSION-mac-arm64.dmg"
DMG_PATH="$RELEASE_DIR/$DMG_NAME"
CHECKSUM_PATH="$DMG_PATH.sha256"

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Required command not found: $1" >&2
    exit 1
  }
}

for command in xcodebuild xcrun security codesign ditto hdiutil osascript shasum; do
  require_command "$command"
done

if [[ -e "$RELEASE_DIR" ]]; then
  echo "Release directory already exists: $RELEASE_DIR" >&2
  echo "Refusing to overwrite an existing release artifact." >&2
  exit 1
fi

source_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/Configuration/Info.plist")"
if [[ "$source_version" != "$VERSION" ]]; then
  echo "Configuration/Info.plist declares $source_version, not requested version $VERSION." >&2
  exit 1
fi
if ! /usr/bin/rg -qF "MARKETING_VERSION = $VERSION;" "$ROOT_DIR/R3Dshot.xcodeproj/project.pbxproj"; then
  echo "The Xcode MARKETING_VERSION does not match $VERSION." >&2
  exit 1
fi
if ! /usr/bin/security find-identity -v -p codesigning | /usr/bin/rg -qF "$SIGNING_IDENTITY"; then
  echo "Developer ID identity is unavailable: $SIGNING_IDENTITY" >&2
  exit 1
fi

mkdir -p "$RELEASE_DIR"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/r3dshot-release.XXXXXX")"
RW_DMG="$TEMP_DIR/$APP_NAME-rw.dmg"
MOUNT_POINT=""

cleanup() {
  if [[ -n "$MOUNT_POINT" && -d "$MOUNT_POINT" ]]; then
    hdiutil detach "$MOUNT_POINT" -quiet || true
  fi
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

echo "Archiving $APP_NAME $VERSION with $SIGNING_IDENTITY"
xcodebuild archive \
  -project "$ROOT_DIR/R3Dshot.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
  CODE_SIGNING_REQUIRED=YES \
  CODE_SIGNING_ALLOWED=YES \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  ENABLE_HARDENED_RUNTIME=YES \
  OTHER_CODE_SIGN_FLAGS='--timestamp'

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "Archive did not contain $APP_NAME.app: $APP_BUNDLE" >&2
  exit 1
fi

app_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_BUNDLE/Contents/Info.plist")"
app_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_BUNDLE/Contents/Info.plist")"
if [[ "$app_bundle_id" != "$BUNDLE_ID" || "$app_version" != "$VERSION" ]]; then
  echo "Archived app metadata does not match the release contract." >&2
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
codesign -dvv --verbose=4 "$APP_BUNDLE" 2>&1 | tee "$RELEASE_DIR/$APP_NAME.codesign.txt"
if ! /usr/bin/rg -qF "Authority=$SIGNING_IDENTITY" "$RELEASE_DIR/$APP_NAME.codesign.txt" \
  || ! /usr/bin/rg -qF "TeamIdentifier=$TEAM_ID" "$RELEASE_DIR/$APP_NAME.codesign.txt" \
  || ! /usr/bin/rg -q 'flags=.*runtime' "$RELEASE_DIR/$APP_NAME.codesign.txt"; then
  echo "The archived app does not meet the Developer ID, team, or Hardened Runtime contract." >&2
  exit 1
fi

APP_NOTARY_ZIP="$TEMP_DIR/$APP_NAME-notary.zip"
APP_NOTARY_JSON="$RELEASE_DIR/$APP_NAME-app-notarization.json"
ditto -c -k --keepParent "$APP_BUNDLE" "$APP_NOTARY_ZIP"
echo "Submitting the signed app to Apple Notary Service (usually a few minutes)."
xcrun notarytool submit "$APP_NOTARY_ZIP" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait \
  --output-format json > "$APP_NOTARY_JSON"
if [[ "$(plutil -extract status raw "$APP_NOTARY_JSON")" != "Accepted" ]]; then
  echo "Apple did not accept the app notarization. Result: $APP_NOTARY_JSON" >&2
  exit 1
fi
xcrun stapler staple "$APP_BUNDLE"
xcrun stapler validate "$APP_BUNDLE"

STAGE_DIR="$TEMP_DIR/stage"
mkdir -p "$STAGE_DIR/.background"
ditto "$APP_BUNDLE" "$STAGE_DIR/$APP_NAME.app"
ln -s /Applications "$STAGE_DIR/Applications"
cp "$ROOT_DIR/LICENSE" "$STAGE_DIR/LICENSE.txt"
printf '%s\n' \
  'Ziehe R3Dshot in den Programme-Ordner.' \
  '' \
  'R3Dshot benötigt beim ersten Aufnehmen die macOS-Berechtigung für Bildschirmaufnahme.' \
  > "$STAGE_DIR/INSTALL R3DSHOT.txt"
xcrun swift "$ROOT_DIR/script/render_dmg_background.swift" \
  "$ROOT_DIR/script/assets/dmg-background.svg" \
  "$STAGE_DIR/.background/background.png"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE_DIR" \
  -fs HFS+ \
  -format UDRW \
  -ov "$RW_DMG" >/dev/null
MOUNT_POINT="$(hdiutil attach "$RW_DMG" -readwrite -noverify -nobrowse | /usr/bin/awk '/\/Volumes\// { print substr($0, index($0, "/Volumes/")); exit }')"
if [[ -z "$MOUNT_POINT" || ! -d "$MOUNT_POINT" ]]; then
  echo "Could not mount the writable DMG." >&2
  exit 1
fi

osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$APP_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {100, 100, 1000, 620}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 104
    set background picture of viewOptions to file ".background:background.png"
    set position of item "$APP_NAME.app" to {200, 260}
    set position of item "Applications" to {700, 260}
    set position of item "INSTALL R3DSHOT.txt" to {450, 410}
    close
  end tell
end tell
APPLESCRIPT

hdiutil detach "$MOUNT_POINT" -quiet
MOUNT_POINT=""
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" >/dev/null
codesign --force --sign "$SIGNING_IDENTITY" --timestamp "$DMG_PATH"

DMG_NOTARY_JSON="$RELEASE_DIR/$APP_NAME-dmg-notarization.json"
echo "Submitting the final DMG to Apple Notary Service (usually a few minutes)."
xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait \
  --output-format json > "$DMG_NOTARY_JSON"
if [[ "$(plutil -extract status raw "$DMG_NOTARY_JSON")" != "Accepted" ]]; then
  echo "Apple did not accept the DMG notarization. Result: $DMG_NOTARY_JSON" >&2
  exit 1
fi
xcrun stapler staple "$DMG_PATH"

DMG_SHA256="$(shasum -a 256 "$DMG_PATH" | /usr/bin/awk '{ print $1 }')"
printf '%s  %s\n' "$DMG_SHA256" "$DMG_NAME" > "$CHECKSUM_PATH"
"$ROOT_DIR/script/verify_release.sh" "$VERSION" DMG "$DMG_PATH" "$CHECKSUM_PATH"

echo "Release artifact verified: $DMG_PATH"
echo "SHA-256: $DMG_SHA256"
