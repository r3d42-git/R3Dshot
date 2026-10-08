# DMG artwork and layout

`dmg-background.svg` is rendered by `script/render_dmg_background.swift`.

`dmg-layout.dsstore` preserves the Finder layout from the published, signed
R3Dshot 0.1.1 DMG. The release script copies it as `.DS_Store` before creating
the image. The volume name, app/link/instructions names and relative background
path remain unchanged. This keeps the existing design without opening or
automating Finder during packaging. Verify the mounted DMG visually if these
names or the artwork change.
