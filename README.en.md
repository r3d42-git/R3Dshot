# R3Dshot

R3Dshot is a native macOS screenshot tool with a menu-bar workflow, global keyboard shortcuts, and non-destructive annotation.

Deutsche Fassung: [README.md](README.md)

## System requirements

- Apple Silicon Mac
- macOS 15.2 or later
- Xcode 26.6 or later for local development

## Current development status

The implemented editor phases cover the menu-bar app, configurable global triggers, Screen Recording permission, and area, window, and screen capture. Screenshots open in independent editor windows and can be saved as PNG files, copied to the clipboard, or passed on through Quick Action.

The editor is non-destructive. Rectangles, ellipses, arrows, markers, redactions, text, speech bubbles, step markers, pixelation, and focus effects can be created, selected, moved, resized or adjusted, styled, duplicated, arranged, and deleted. Cropping, undo/redo, zoom, the inspector, and saving or copying the rendered result are also available.

The Dock/menu-bar lifecycle regression and the confirmation check for Quit have been resolved.

This working state extends the editor with:

- Multi-selection: Command-click adds objects to, or removes them from, the selection. The combined selection can be moved as one rigid group, deleted, copied, pasted, duplicated, and arranged in the stacking order. A selection consisting only of step markers can change its shape together.
- Step markers: Circle, square, and rounded-square variants are available. Their number is optically centred and scales automatically when the marker is enlarged or reduced. The Step tool remains active after placement so consecutive numbers can be placed; clicking the Select tool ends that mode. The starting number is chosen before the first marker is placed, allowing a sequence to begin at, for example, 5.
- Cropping: In addition to freeform cropping, the optional 1:1, 16:9, and 4:3 aspect ratios are available; they apply when drawing and when resizing with the handles.

## Build and run locally

    ./script/build_and_run.sh

The optional `--verify`, `--logs`, `--telemetry`, and `--debug` modes are available for process checks and diagnostics.

Run the document/renderer smoke test with:

    ./script/test_editor_model.sh

If an Apple Development identity is available in the local keychain, the script uses it automatically. This preserves the macOS Screen Recording permission for later debug builds. Set `R3DSHOT_CODE_SIGN_IDENTITY` to select a different local identity.

## License

R3Dshot is licensed under GPL-3.0-or-later. The full license text is in [LICENSE](LICENSE).
