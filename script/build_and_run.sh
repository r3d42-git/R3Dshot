#!/usr/bin/env bash
set -euo pipefail

MODE=run
if [[ $# -gt 0 ]]; then
  MODE="$1"
fi

APP_NAME="R3Dshot"
BUNDLE_ID="org.r3d.R3Dshot"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/DerivedData"
APP_BUNDLE="$BUILD_DIR/Build/Products/Debug/$APP_NAME.app"

# A stable Apple Development signature gives TCC a stable designated
# requirement. Ad-hoc signatures use the changing cdhash instead, which makes
# Screen Recording consent appear to disappear after a rebuilt debug app is
# relaunched. A developer can explicitly override this selection when needed.
LOCAL_SIGNING_IDENTITY="${R3DSHOT_CODE_SIGN_IDENTITY:-}"
if [[ -z "$LOCAL_SIGNING_IDENTITY" ]]; then
  LOCAL_SIGNING_IDENTITY="$(
    /usr/bin/security find-identity -v -p codesigning 2>/dev/null \
      | /usr/bin/sed -n 's/.*"\(Apple Development:.*\)"/\1/p' \
      | /usr/bin/head -n 1 \
      || true
  )"
fi

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

XCODEBUILD_ARGS=(
  -project "$ROOT_DIR/R3Dshot.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Debug \
  -derivedDataPath "$BUILD_DIR" \
  build
)

if [[ -n "$LOCAL_SIGNING_IDENTITY" ]]; then
  echo "Using stable local signing identity: $LOCAL_SIGNING_IDENTITY"
  XCODEBUILD_ARGS+=(
    CODE_SIGN_IDENTITY="$LOCAL_SIGNING_IDENTITY"
    CODE_SIGNING_REQUIRED=YES
  )
else
  echo "No Apple Development identity found; using the project's ad-hoc debug signature." >&2
fi

xcodebuild "${XCODEBUILD_ARGS[@]}"

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
