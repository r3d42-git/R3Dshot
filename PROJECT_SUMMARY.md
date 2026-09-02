# R3Dshot – Projektübergabe

Stand: 3. September 2026

## Als Nächstes

Phase 7 ist abgeschlossen. Die nächste Produktphase ist noch nicht festgelegt.

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
- Marker bleiben beim Skalieren kreisförmig, können verschoben werden und sind im Inspector über Füll- und Zahlenfarbe anpassbar. Die Zahl wird aus den tatsächlichen Glyphengrenzen optisch zentriert und skaliert automatisch mit der Markergröße; eine separate Schriftgrößen-Einstellung gibt es nicht mehr.
- Neue Marker erhalten fortlaufende Nummern. Eine Änderung der Nummer im Inspector ordnet die Schritte ohne Duplikate oder Lücken um; Duplizieren und Einsetzen erhalten die nächste freie Nummer, Löschen nummeriert die verbleibenden Schritte nach.

### Phase 7: Mehrfachauswahl, Schrittformen und Seitenverhältnisse

Erledigt:

- Die Auswahl ist eine Menge stabiler Annotation-IDs. Mit ⌘-Klick lassen sich Objekte zur Auswahl hinzufügen oder aus ihr entfernen; ein normaler Zug auf einem Mitglied verschiebt die gesamte Auswahl starr und an den Bildgrenzen geklemmt.
- Löschen, Kopieren/Einsetzen, Duplizieren sowie Vor-/Zurück-Anordnen wirken auf die ganze Auswahl. Der Inspector zeigt bei Mehrfachauswahl die gemeinsamen Aktionen; bei ausschließlich ausgewählten Schrittmarkierungen lässt sich ihre Form gemeinsam ändern. Gemischte Auswahl bleibt vor typbezogenen Änderungen geschützt.
- Schrittmarker können Kreis, Quadrat oder abgerundetes Quadrat sein. Die Form ist codierbar, rendert auf dem gemeinsamen Preview-/Exportpfad und ältere oder unbekannte gespeicherte Formwerte fallen sicher auf Kreis zurück.
- Die Schrittzahl hat kein separates Größenattribut mehr: Der Renderer leitet sie proportional aus der Markergröße ab, begrenzt sie bei mehrstelligen Zahlen innerhalb der Innenfläche und zentriert sie über optische Glyphengrenzen. Ältere Dokumente mit `fontSize` laden weiterhin; der inzwischen wirkungslose Wert wird beim erneuten Speichern entfernt.
- Eine Mehrfachauswahl ausschließlich aus Schrittmarkierungen zeigt im Inspector die gemeinsame Form. Bei gemischten Formen steht dort „Gemischt“; eine Auswahl vereinheitlicht alle markierten Schritte in einem Undo-Schritt.
- Bei einer gemischten Mehrfachauswahl stehen Auswahlhinweis und Anordnungsaktionen in einem vertikalen Layout mit Trennlinie. Die Aktionen werden nicht mehr über den mehrzeiligen Hinweis gelegt, auch nicht im schmalen Inspector.
- Das Schrittwerkzeug bleibt nach dem Setzen aktiv. Vor dem ersten Marker ist die Startnummer wählbar; eine bei 5 begonnene Folge bleibt auch beim Umordnen, Duplizieren, Einsetzen, Löschen sowie Undo/Redo bei ihrer Basisnummer.
- Der Crop-Inspector bietet freien Zuschnitt sowie 1:1, 16:9 und 4:3. Die Vorgabe beschränkt sowohl einen neu aufgezogenen Ausschnitt als auch die vier Skaliergriffe.

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

Beide Befehle waren am 2. September 2026 erfolgreich. Der Smoke-Test umfasst zusätzlich die präzise Pixelierungs-/Fokus-Prüfung einschließlich Crop, die Schrittform-Codable-Kompatibilität und sichtbare Ausgabe aller drei Formen sowie die drei Crop-Verhältnisse. Der Build nutzt die lokale Apple-Development-Signatur und prüft anschließend den gestarteten Prozess.

Die Ergänzung für die gemeinsame Schrittform wurde anschließend mit einem isolierten Debug-Build des aktuellen Arbeitsstands (`CODE_SIGNING_ALLOWED=NO`, temporäres DerivedData) erfolgreich kompiliert. Die laufende Editor-App wurde dabei bewusst nicht beendet.

Die Korrektur der Aktionsüberlagerung bei gemischter Mehrfachauswahl wurde am 3. September zusätzlich mit `./script/test_editor_model.sh` und einem isolierten Debug-Build (`CODE_SIGNING_ALLOWED=NO`, temporäres DerivedData) erfolgreich geprüft; die laufende Editor-App blieb dabei ebenfalls unangetastet.

Die vereinfachten, automatisch mitskalierenden Schrittzahlen wurden am 3. September mit dem erweiterten Smoke-Test (optische Zentrierung von `1`, `3`, `8`, `12`, `9999`, kleine/Standard/große Marker und alte Dokumente mit `fontSize`) sowie `./script/build_and_run.sh --verify` erfolgreich geprüft und frisch gestartet.

Manuelle Editorprüfung mit der frisch gebauten App:

- Pixelierung angelegt, Pixelgröße verändert, verschoben, skaliert sowie per Undo/Redo zurück- und wiederhergestellt.
- Fokus angelegt und den Blur-Radius verändert; der markierte Bereich blieb scharf, das Umfeld wurde weichgezeichnet.
- Schrittmarker per Klick angelegt, automatisch als 1 und 2 nummeriert, im Inspector umsortiert, dupliziert (3), gelöscht und anschließend lückenlos nachnummeriert; proportionale Skalierung blieb kreisförmig.
- PNG-Export visuell und technisch geprüft: `build/manual-phase5-6-check.png`, 859 × 621 px, RGBA-PNG.

Die bis Phase 6 vorhandenen Funktionen wurden laut Nutzer vor Beginn dieser Phase vollständig manuell getestet und bestätigt. Phase 7 ist durch Modell-/Renderer-Smoke-Test und einen frischen Debug-Build geprüft; eine neue manuelle Editorabnahme für die zusätzlichen Interaktionen steht noch aus.

Test-App:

`/Volumes/Media/codex/R3Dshot/build/DerivedData/Build/Products/Debug/R3Dshot.app`

## Release 0.1.0

- Öffentliches Repository: https://github.com/r3d42-git/R3Dshot
- Tag und Release-Commit: `v0.1.0` → `714e4cd22e0242895b0980956fbdcf75686c7d87`
- Asset: [R3Dshot-0.1.0-mac-arm64.dmg](https://github.com/r3d42-git/R3Dshot/releases/download/v0.1.0/R3Dshot-0.1.0-mac-arm64.dmg)
- SHA-256: `ce7f96432473de79cb7a3a7616647c5aca6731e80309a2033cdf7185c7a3ec7f`
- Architektur und Produktidentität: `arm64`, `org.r3d.R3Dshot`, macOS 15.2 oder neuer.
- Signatur: `Developer ID Application: Philipp John Hild (G6JH37W285)`, Hardened Runtime und sicherer Zeitstempel.
- Apple-Notarisierung: App-ZIP `41607217-5610-42eb-9e4b-5019b5ce545c`, DMG `e3bdc13e-bcf8-487e-a5d2-33b65116dc42`; beide `Accepted`.
- Das Ticket ist sowohl an der App vor dem Verpacken als auch am finalen DMG gestapelt. Lokaler DMG und frischer GitHub-Download bestanden `codesign`, `hdiutil verify`, `stapler validate` und Gatekeeper; die Prüfungen mounteten jeweils genau den geprüften DMG und validierten die enthaltene App.

## Commits dieses Abschlusses

- `3036a5b Add pixelation and focus effects`
- `e035d0e Improve step marker workflow`
- `80d6817 Implement phase 7 editor workflow`
- `7f67cd4 Add notarized DMG release workflow`
- `714e4cd Fix release tool preflight`

Die Release-Nachweise stehen bewusst in diesem nachträglichen, dokumentationsreinen Commit; der veröffentlichte Tag bleibt auf `714e4cd`.

## Noch offen

- Physische Nachabnahme der Bereichs-, Fenster- und Bildschirmaufnahme auf den vorgesehenen Displays. Phase 7 ändert keine Hardware-Erkennung; die bestehenden Capture-Workflows waren bereits bestätigt.
- Manuelle Phase-7-Abnahme: ⌘-Mehrfachauswahl samt Gruppenverschieben, gemeinsame Schrittform bei mehreren Markern, die drei Schrittformen, Start bei einer gewählten Zahl sowie alle Crop-Verhältnisse anlegen und an den Griffen skalieren.
- Ein Clean-Machine-Start des frisch aus GitHub geladenen DMG wurde nicht durchgeführt. Die notarisierten Container- und Gatekeeper-Prüfungen des lokalen und heruntergeladenen DMG sind dagegen vollständig erfolgt.
