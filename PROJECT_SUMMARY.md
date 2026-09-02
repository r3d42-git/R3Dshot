# R3Dshot – Projektübergabe

Stand: 2. September 2026

## Als Nächstes

Phase 5 und 6 sind abgeschlossen. Die nächste Produktphase ist noch nicht festgelegt.

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

Erledigt: Sprechblasen ergänzen Text mit Rahmen und über den Inspector beweglichem Zeiger. Schrittmarker sind nummerierte, verschiebbare Kreismarken mit korrigierbarer Zahl.

### Phase 5: Pixelierung und Fokus

Erledigt:

- Pixelierung wirkt ausschließlich innerhalb ihres Rechtecks; der Inspector bietet eine Pixelgröße von 2 bis 80 px.
- Fokus lässt den markierten Bereich scharf und weichzeichnet die bereits aufgebaute Komposition außerhalb davon; der Blur-Radius ist im Inspector einstellbar.
- Beide Effekte sind reguläre Annotationen: Z-Reihenfolge, Auswahl, Verschieben, Skalieren, Undo/Redo, Copy/Paste und Crop verwenden weiterhin dieselbe Dokumentrepräsentation.
- Der Renderer zeichnet Effekt-Snapshots auch nach einem Crop im korrekten Exportkoordinatensystem zurück. Die gezielten Smoke-Tests prüfen Pixelierung nur innerhalb ihres Rechtecks und Fokus mit scharfem Inneren sowie weichem Äußeren im zugeschnittenen Export.

### Phase 6: Schrittmarker

Erledigt:

- Ein Klick setzt einen gut erkennbaren, festen kreisförmigen Schrittmarker mit 44 px Startgröße; Aufziehen ist nicht mehr nötig.
- Marker bleiben beim Skalieren kreisförmig, können verschoben werden und sind im Inspector über Füllfarbe, Zahlenfarbe und Schriftgröße anpassbar.
- Neue Marker erhalten fortlaufende Nummern. Eine Änderung der Nummer im Inspector ordnet die Schritte ohne Duplikate oder Lücken um; Duplizieren und Einsetzen erhalten die nächste freie Nummer, Löschen nummeriert die verbleibenden Schritte nach.

## Bestätigter Stand

- Bereichs-, Fenster- und Bildschirmaufnahme funktionieren.
- Das native Fadenkreuz der Bereichsauswahl funktioniert.
- Rechteck, Ellipse, Pfeil/Linie, Schwärzung und Marker funktionieren im Editor.
- Der Marker unterstützt Freihandzeichnen und automatisches horizontales Einrasten.
- Lebenszyklus, Crop, Text, Sprechblasen und Schrittmarker waren vor Beginn dieser Phase bereits manuell bestätigt und blieben im Editor unverändert funktionsfähig.

## Lokale Prüfung

```sh
./script/test_editor_model.sh
./script/build_and_run.sh --verify
```

Beide Befehle waren am 2. September 2026 erfolgreich. Der Smoke-Test umfasst zusätzlich die präzise Pixelierungs-/Fokus-Prüfung einschließlich Crop und Codable-Round-Trip. Der Build nutzt die lokale Apple-Development-Signatur und prüft anschließend den gestarteten Prozess.

Manuelle Editorprüfung mit der frisch gebauten App:

- Pixelierung angelegt, Pixelgröße verändert, verschoben, skaliert sowie per Undo/Redo zurück- und wiederhergestellt.
- Fokus angelegt und den Blur-Radius verändert; der markierte Bereich blieb scharf, das Umfeld wurde weichgezeichnet.
- Schrittmarker per Klick angelegt, automatisch als 1 und 2 nummeriert, im Inspector umsortiert, dupliziert (3), gelöscht und anschließend lückenlos nachnummeriert; proportionale Skalierung blieb kreisförmig.
- PNG-Export visuell und technisch geprüft: `build/manual-phase5-6-check.png`, 859 × 621 px, RGBA-PNG.

Test-App:

`/Volumes/Media/codex/R3Dshot/build/DerivedData/Build/Products/Debug/R3Dshot.app`

## Commits dieses Abschlusses

- `3036a5b Add pixelation and focus effects`
- `e035d0e Improve step marker workflow`

## Noch offen

- Vor einer Veröffentlichung: erneute physische Abnahme der Bereichs-, Fenster- und Bildschirmaufnahme auf den vorgesehenen Displays. Phase 5/6 ändert keine Hardware-Erkennung; die bestehenden Capture-Workflows waren bereits bestätigt.
- Keine Veröffentlichung, kein GitHub-Push und keine Notarisierung wurden durchgeführt.
