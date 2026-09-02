#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="${TMPDIR:-/tmp}/r3dshot-editor-model-smoke"

xcrun swiftc \
  "$ROOT_DIR/R3Dshot/Editor/Document/ScreenshotDocument.swift" \
  "$ROOT_DIR/R3Dshot/Editor/Rendering/ScreenshotRenderer.swift" \
  "$ROOT_DIR/script/EditorModelSmoke/main.swift" \
  -o "$OUTPUT"

"$OUTPUT"
