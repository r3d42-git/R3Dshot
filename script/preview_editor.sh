#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PREVIEW_DIR="$ROOT_DIR/build/editor-redesign"
PREVIEW_APP="$PREVIEW_DIR/R3Dshot Editor Preview.app"
mkdir -p "$PREVIEW_APP/Contents/MacOS"
xcrun swiftc -parse-as-library -module-cache-path "$PREVIEW_DIR/module-cache" \
  "$ROOT_DIR/R3Dshot/Capture/CapturedScreenshot.swift" \
  "$ROOT_DIR/R3Dshot/Storage/PendingCapture.swift" \
  "$ROOT_DIR/R3Dshot/Editor/Document/ScreenshotDocument.swift" \
  "$ROOT_DIR/R3Dshot/Editor/Rendering/ScreenshotRenderer.swift" \
  "$ROOT_DIR/R3Dshot/Editor/EditorToolDefaults.swift" \
  "$ROOT_DIR/R3Dshot/Editor/EditorStore.swift" \
  "$ROOT_DIR/R3Dshot/Editor/EditorWindow.swift" \
  "$ROOT_DIR/R3Dshot/Editor/EditorAppearance.swift" \
  "$ROOT_DIR/R3Dshot/Editor/EditorView.swift" \
  "$ROOT_DIR/R3Dshot/Editor/EditorToolPalette.swift" \
  "$ROOT_DIR/R3Dshot/Editor/Canvas/CanvasTransform.swift" \
  "$ROOT_DIR/R3Dshot/Editor/Canvas/AnnotationCanvas.swift" \
  "$ROOT_DIR/R3Dshot/Editor/Canvas/EditorCanvasView.swift" \
  "$ROOT_DIR/R3Dshot/Editor/Inspector/RectangleInspectorView.swift" \
  "$ROOT_DIR/R3Dshot/Editor/Inspector/ToolDefaultsInspector.swift" \
  "$ROOT_DIR/script/EditorPreview/main.swift" \
  -o "$PREVIEW_APP/Contents/MacOS/EditorPreview"
cat > "$PREVIEW_APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>EditorPreview</string>
<key>CFBundleIdentifier</key><string>org.r3d.R3Dshot.EditorPreview</string>
<key>CFBundleName</key><string>R3Dshot Editor Preview</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>LSMinimumSystemVersion</key><string>15.2</string>
</dict></plist>
PLIST
codesign --force --sign - "$PREVIEW_APP"
if [[ "${1:-}" != "--build-only" ]]; then
  open "$PREVIEW_APP"
fi
