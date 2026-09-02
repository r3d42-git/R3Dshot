# R3Dshot – Projektübergabe

Stand: 2. September 2026

## Als Nächstes

Phase 3 ist abgeschlossen. Als Nächstes folgt Phase 4: Sprechblasen und Schrittmarker.

### Erledigt: App-Lifecycle und sicheres Beenden

- Der Aktivierungszustand wird zentral aus den offenen Editorfenstern abgeleitet: Nur ein offener Editor macht R3Dshot zur regulären Dock-App.
- Das Einstellungsfenster bleibt sichtbar und aktivierbar, ohne dauerhaft ein Dock-Symbol zu erzeugen.
- Das Schließen des letzten Editors kehrt zuverlässig zur Menüleisten-App zurück.
- Menüpunkt „R3Dshot beenden“ und Command-Q führen durch dieselbe Abfrage: **In Menüleiste behalten**, **R3Dshot beenden** oder **Abbrechen**.
- Beim Behalten oder vollständigen Beenden laufen Editoren weiter durch ihre bestehende Sichern-/Verwerfen-/Abbrechen-Abfrage; Änderungen werden nicht stillschweigend verworfen.

### Phase 2: Zuschneiden

Erledigt: Crop bleibt ein einzelner Dokumentzustand in Bildpixeln, nicht ein Annotationselement. Toolbar, Canvas-Griffe, Inspector, Undo/Redo sowie Preview/PNG-Renderer sind verbunden. Der Renderer exportiert den Ausschnitt in korrekter Größe und verschiebt/clipt Annotationen deterministisch.

### Phase 3: Text

Erledigt: Text ist ein codierbares Element mit Inhalt, Systemschrift, Größe, Farbe, Ausrichtung und Deckkraft. Inspector, Renderer, Auswahl, Skalierung sowie Copy/Paste nutzen dieselbe Dokumentrepräsentation.

### Phase 4: Callouts

- Sprechblasen ergänzen Text mit einem Rahmen und verschiebbarem Zeiger.
- Schrittmarker sind nummerierte, verschiebbare Kreismarken mit korrigierbarer Zahl.

## Bestätigter Stand

- Bereichs-, Fenster- und Bildschirmaufnahme funktionieren.
- Das native Fadenkreuz der Bereichsauswahl funktioniert.
- Rechteck, Ellipse, Pfeil/Linie, Schwärzung und Marker funktionieren im Editor.
- Der Marker unterstützt Freihandzeichnen und automatisches horizontales Einrasten.
- Modell-/Renderer-Smoke-Test und signierter lokaler Build sind für den Initialstand und Phase 1 erfolgreich.

## Lokale Prüfung

```sh
./script/test_editor_model.sh
./script/build_and_run.sh --verify
```

Test-App:

`/Volumes/Media/codex/R3Dshot/build/DerivedData/Build/Products/Debug/R3Dshot.app`
