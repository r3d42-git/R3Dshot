#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/r3dshot-editor-workflow.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
xcrun swiftc -parse-as-library -module-cache-path "$TEST_DIR/module-cache" \
  "$ROOT_DIR/R3Dshot/Capture/CapturedScreenshot.swift" \
  "$ROOT_DIR/R3Dshot/Storage/PendingCapture.swift" \
  "$ROOT_DIR/R3Dshot/Editor/Document/ScreenshotDocument.swift" \
  "$ROOT_DIR/R3Dshot/Editor/EditorToolDefaults.swift" \
  "$ROOT_DIR/R3Dshot/Editor/EditorStore.swift" \
  "$ROOT_DIR/R3Dshot/Editor/Canvas/CanvasTransform.swift" \
  "$ROOT_DIR/R3Dshot/Editor/EditorWindow.swift" \
  "$ROOT_DIR/script/EditorWorkflowSmoke/main.swift" \
  -o "$TEST_DIR/editor-workflow-smoke"
"$TEST_DIR/editor-workflow-smoke"
