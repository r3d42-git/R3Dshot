#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/r3dshot-selection-smoke.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT

xcrun swiftc -parse-as-library -module-cache-path "$TEST_DIR/module-cache" \
  "$ROOT_DIR/R3Dshot/Capture/SelectionOverlayController.swift" \
  "$ROOT_DIR/script/SelectionOverlaySmoke/main.swift" \
  -o "$TEST_DIR/selection-overlay-smoke"

"$TEST_DIR/selection-overlay-smoke"
