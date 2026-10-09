# Release profile

- Repository: `r3d42-git/R3Dshot`; release branch: `main`.
- Xcode app: `org.r3d.R3Dshot`, arm64, macOS 15.2+.
- Version sources: `Configuration/Info.plist` and both configurations in
  `R3Dshot.xcodeproj/project.pbxproj`. Increment marketing and build versions.
- Gates: `./script/test_editor_model.sh`, `./script/test_editor_workflow.sh`,
  `./script/test_selection_overlay.sh`
  (logged-in graphical session with an agreed quiet interval), `git diff --check`, scoped source review.
- Local packaging: `./script/release.sh VERSION`. Existing G2 Developer ID,
  team `G6JH37W285`, notary Keychain profile `R3Dshot`; no credentials in Git.
  The app is notarized and stapled before packaging, then the DMG is separately
  signed, notarized and stapled. The fixed Finder layout preserves the previous
  installer design without UI automation.
- Local gate: `./script/verify_release.sh VERSION DMG` checks the exact DMG and
  its mounted app, including tickets, Gatekeeper, identity, architecture and hash.
- Commit approved source, push `main`, create/push annotated `vVERSION` on that
  commit. Run `./script/publish_release.sh VERSION --dry-run`, then the same
  command without `--dry-run`. The wrapper uploads DMG/checksum, compares GitHub's
  digest and verifies a fresh download.
- Record final hashes, submission IDs, tag/commit and validation boundaries in
  `PROJECT_SUMMARY.md` with a follow-up documentation commit. Never move a
  published tag. A release request authorizes publication; a local build alone
  does not.
