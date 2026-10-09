# R3Dshot – Projektübergabe

Stand: 10. Oktober 2026

## Abgeschlossenes Release 0.2.0 (10. Oktober 2026)

- [R3Dshot 0.2.0](https://github.com/r3d42-git/R3Dshot/releases/tag/v0.2.0) veröffentlicht, kein Draft/Prerelease. Release-Commit `e267b3c53ead591c51ef0fba8f55a2f6b45203f4` auf `main`; annotierter Tag `v0.2.0` bleibt unverändert auf diesem Commit. Abschlussnachweise folgen separat als Dokumentations-Commit.
- Inhalt: vom Nutzer bestätigter Editor mit Werkzeugpalette links, Werkzeugvorgaben, abgestuftem Dunkelblau einschließlich Titelleiste, verbessertem Zoom/Shortcut-Fokus/Erfolgsfeedback und korrigierter Vorschau beim Appearance-Wechsel; außerdem die sichtbare Fadenkreuz-Korrektur beim Aufnahmebeginn.
- Version/Build `0.2.0/4`, Bundle-ID `org.r3d.R3Dshot`, arm64, macOS 15.2+. Asset: [R3Dshot-0.2.0-mac-arm64.dmg](https://github.com/r3d42-git/R3Dshot/releases/download/v0.2.0/R3Dshot-0.2.0-mac-arm64.dmg), dazu `.dmg.sha256`; SHA-256 `bdae3a9c80b14250d868cf9a8c8ff84c3a0f5b677656ccbdbe19542c45c63c65`.
- Signierung: `Developer ID Application: Philipp John Hild (G6JH37W285)`, bestehendes G2-Leaf `D548540E7FE1BD9B3C4518CC02D8786E1BFEB885`, Hardened Runtime und sicherer Zeitstempel. Apple-App-Submission `b84a7247-ed15-4b00-9bd0-d755e3614b56`, DMG-Submission `65988428-372e-49c8-b62d-31f5795b6faa`: beide `Accepted`. App-Ticket vor Verpackung angeheftet; finale App und finales DMG jeweils mit gültigem angeheftetem Ticket.
- Repository-Ablauf `release.sh`, `publish_release.sh --dry-run`, `publish_release.sh` erfolgreich. Lokales sowie unabhängig frisch heruntergeladenes DMG geprüft: SHA-256/GitHub-Digest, Containerintegrität, Signaturen, Stapling, Gatekeeper (`Notarized Developer ID`), Bundle-ID/Version/arm64 der exakt gemounteten App sowie Finder-Layout/Hintergrund. Release-Metadaten und Remote-Tagziel abschließend bestätigt. Keine CI-Pipeline; lokal gebaut und veröffentlicht.
- Bereits vor Freigabe erfolgreiche Modell-/Renderer-, Editor-Workflow- und native Auswahltests sowie statische Prüfung und reale Editor-Sichtprüfung wurden für denselben Produktquellstand übernommen; für das Release nur Versionsquellen/Dokumentation ergänzt. Nutzer bestätigt lokale Funktion und Gestaltung. Kein Clean-Machine-Start und keine zusätzliche physische Mehrdisplay-Abnahme. Die laufende lokale Test-App wurde für die Veröffentlichung nicht erneut beendet oder ersetzt.
- Die automatische Freigabeprüfung blockierte den ersten Release-Aufruf vor Ausführung wegen der Apple-Übermittlung. Nach ausdrücklichem „reich bitte ein“ wurde der unveränderte Repository-Ablauf erfolgreich ausgeführt. Davor rein lokales signiertes Vorabarchiv unter `build/ReleasePreflight` erstellt; keine Einstellungen, Schlüsselbundprofile oder Sicherheitsvorgaben geändert. Dies war eine Ausführungsfreigabegrenze, kein Fehler im Release-Skript.

## Editor-Neugestaltung (10. Oktober 2026, lokal abgenommen)

- Nutzer wählte Variante mit Werkzeugen links; anschließend ausdrücklich etwas helleres Dunkelblau für das gesamte Editorfenster einschließlich Titelleiste gewünscht. Zwölf Werkzeuge jetzt links in vier Gruppen, beschriftete Aktionen oben, kontextabhängige Eigenschaften rechts und kompakte Status-/Zoomzeile unten.
- `EditorAppearance` bündelt adaptive Oberflächen: Arbeitsfläche #25364A, Seitenflächen #2C3F55, Titelleiste #344960; im hellen Modus native Systemfarben. Native Fensterfarbe/transparentes Titelbar-Chrome und SwiftUI-Toolbar sind abgestimmt.
- `EditorToolDefaults` und `ToolDefaultsInspector` erlauben Einstellungen vor dem Zeichnen für alle zehn Annotationsarten, einschließlich Textinhalt. Vorgaben gelten je Editorfenster; bestehende Elemente und Dokumentformat bleiben erhalten. Schrittmarkierungen verwenden weiterhin die fortlaufende Nummerierung.
- Zoom unterscheidet Anpassen, 100 % und freie Vergrößerung; 100 % bedeutet einen Bildpixel pro physischem Displaypixel. Neuer fensterlokaler `EditorWindow` ordnet Annotation-Shortcuts zu und lässt native Textfelder ihre eigenen Befehle verarbeiten. Klick auf die Arbeitsfläche beendet den Textfeldfokus. Erfolgsfeedback nach echtem Sichern/Kopieren.
- Isolierte native Vorschau über `./script/preview_editor.sh`, eigene Bundle-ID, synthetisches Testbild, ohne Capture-Hotkeys/TCC/Benutzerdaten. Sichern/Kopieren in dieser Vorschau sind ausdrücklich nur Feedback-Stubs; tatsächlicher Export wird durch den unveränderten Produktionscontroller und Modell-/Renderer-Test abgedeckt.
- GUI geprüft: Werkzeugvorgabe auf neue Rechtecke übernommen, Undo/Redo, Texteingabe/Löschtaste und anschließendes Löschen des Elements nach Canvas-Klick, Palette bei 720 × 480, große Ansicht, 100-%-Ansicht, blaue Titelleiste/Seitenflächen sowie Hell→Dunkel. Beim Appearance-Wechsel wurde ein leer werdendes Bild reproduziert: Schatten auf gesamter Bildkomposition verursachte die Störung; separater Schatten-Hintergrund behält die Bildanzeige in beiden Richtungen bei.
- `./script/test_editor_workflow.sh` prüft Vorgaben, Geometrie, Nummerierung, Undo/Redo, Auswahlwechsel, Retina-Zoommathematik und Tastenzuordnung; erfolgreich. `./script/test_editor_model.sh` ebenfalls erfolgreich. Unabhängige statische Editorprüfung ohne konkreten Regressionsbefund. Keine neue physische Mehrdisplay-Abnahme.
- Vollständiger Release-Konfigurationsbuild `build/EditorRedesignBuild/Build/Products/Release/R3Dshot.app` erfolgreich; Developer-ID G2, Hardened Runtime, strikte Signaturprüfung erfolgreich und Designated Requirement identisch zur installierten App. Binary-SHA-256 `0d5ed8e87bc66ca07f3a1840bfeaf1812642a94d823d03c46a33300f36684e8f`. Version/Build weiterhin 0.1.2/3.
- Nach bestätigtem regulärem Beenden lokal unter `/Applications/R3Dshot.app` installiert und neu gestartet. Installiertes Binary entspricht dem geprüften Hash; Preferences-Datei beim Austausch unverändert. Rückfallkopie: `/Applications/.r3dshot-editor-update.hbdfpmqj/Previous.app`. Die Cursor-Korrektur ist enthalten. Separate Testvorschau geschlossen. Nutzer bestätigt: deutlich besser und funktioniert. Anschließend vollständiges Commit/Push/Release beauftragt. Veröffentlichung als 0.2.0/4 ist abgeschlossen (siehe oben).

## Lokale Cursor-Korrektur (10. Oktober 2026)

- Nutzer meldete: Auswahl nach Print funktioniert, sichtbarer Cursor bleibt jedoch ein Pfeil. Reproduziert mit dem echten Overlay nach vorheriger Deaktivierung: App-lokales `NSCursor.current` war Fadenkreuz, `NSCursor.currentSystem` zeigte ein anderes Bild (28 × 40 statt 24 × 24). Der bisherige Fokus-Test erkannte diese Abweichung nicht.
- Ursache: Die in 0.1.2 eingeführten nichtaktivierenden Panels erhalten Tastaturfokus, jedoch nicht zuverlässig die sichtbare Cursorzuständigkeit. `SelectionOverlayController` aktiviert die App wieder einmalig beim Auswahlstart und erneuert nach dem Event-Loop-Wechsel den Cursor auch bei bereits vorhandenem Tastaturfokus. UUID-Schutz, begrenzte Fokuswiederholung, Abbruch bei Fokusverlust und Unterbrechungsbeobachter bleiben erhalten. Nach regulärem Abschluss wird die vorherige App nur dann reaktiviert, wenn die Auswahl noch den Fokus besitzt und R3Dshot weiterhin vorne ist; ein bewusster App-/Fensterwechsel wird nicht rückgängig gemacht.
- Zusätzlich die laut SDK unzulässige Tracking-Kombination `.activeAlways + .cursorUpdate` getrennt: Pointerereignisse bleiben immer aktiv, Cursorupdates folgen dem Key-Panel. Diese Änderung allein war im A/B-Test nicht ausreichend; erst die explizite Aktivierung korrigierte den Systemcursor dauerhaft.
- Im vom Nutzer freigegebenen GUI-Testfenster bestanden: sechs zeitversetzte Vergleiche des tatsächlichen Systemcursorbilds sowie der erweiterte `./script/test_selection_overlay.sh` (inaktiver Start, Cursor, Fokusübergabe/-verlust, Ersatz, alte Ereignisse, Unterbrechungen). `./script/test_editor_model.sh` und `git diff --check` ebenfalls erfolgreich. Sandbox ohne GUI-/Cachezugriff liefert keine gültige Laufzeitabnahme; die unveränderten Tests bestanden außerhalb der Sandbox.
- Vollständiger Release-Konfigurationsbuild unter `build/CursorFixBuild/Build/Products/Release/R3Dshot.app` erfolgreich, mit vorhandener G2-Developer-ID und Hardened Runtime signiert. Strikte Signaturprüfung erfolgreich, Designated Requirement identisch zur installierten App. Einziger Build-Hinweis: übersprungene AppIntents-Metadatenextraktion. Binary-SHA-256 `8e313068bd9517066ded8dff74a1722d8532e68a284f4bb6d9b38d8abd156df8`.
- Nach ausdrücklich bestätigtem regulärem Beenden lokal installiert und neu gestartet. Installiertes Binary entspricht dem geprüften Hash, Preferences-Datei beim Austausch unverändert. Rückfallkopie: `/Applications/.r3dshot-cursor-update.hfQgZ9/Previous.app`.
- Lokaler Fix, weiterhin Version/Build 0.1.2/3; kein Commit, Push, Release oder neue Notarisierung. Der ursprüngliche Release-Tag bleibt unverändert. Nutzer meldet nach Installation, dass es scheinbar funktioniert; physische Mehrdisplay- und kurzlebige Menü-/Popover-Aufnahmen sind durch die automatischen Tests nicht separat abgenommen.

## Abgeschlossenes Release 0.1.2 (8. Oktober 2026)

- [R3Dshot 0.1.2](https://github.com/r3d42-git/R3Dshot/releases/tag/v0.1.2) veröffentlicht, kein Draft/Prerelease. Release-Commit `450496514759446ee11f0229d0247014fa2b324f` auf `main`; annotierter Tag `v0.1.2` bleibt auf diesem Commit. Abschlussnachweise folgen in einem separaten Dokumentations-Commit.
- Version/Build `0.1.2/3`, Bundle-ID `org.r3d.R3Dshot`, arm64, macOS 15.2+. Asset: [R3Dshot-0.1.2-mac-arm64.dmg](https://github.com/r3d42-git/R3Dshot/releases/download/v0.1.2/R3Dshot-0.1.2-mac-arm64.dmg), dazu `.dmg.sha256`; SHA-256 `1d06cd4007030421985560f58b0b0582a3a1c6de36d40b5e634e19537e7cdde3`.
- Signierung mit `Developer ID Application: Philipp John Hild (G6JH37W285)`, exaktes G2-Leaf `D548540E7FE1BD9B3C4518CC02D8786E1BFEB885`, Hardened Runtime und sicherer Zeitstempel. Apple-App-Submission `fea390ae-2092-4395-84a9-bce2b0539a5c`, DMG-Submission `b33a3070-443e-447d-95ca-5d54ade2c884`: beide `Accepted`. App-Ticket vor Verpackung und zusätzlich DMG-Ticket angeheftet und validiert.
- `release.sh`, `publish_release.sh --dry-run` und Veröffentlichung erfolgreich. Lokales und frisch von GitHub heruntergeladenes DMG vollständig geprüft: SHA-256 und GitHub-Digest identisch, Containerintegrität, Signaturen, beide angehefteten Tickets, Gatekeeper sowie Version/Bundle-ID/arm64 des jeweils exakt gemounteten App-Bundles. Layoutvorlage und Hintergrunddatei im fertigen Paket geprüft. Keine CI-Pipeline vorhanden; Build, Signierung und Veröffentlichung erfolgten lokal.
- Versionsquellen aktualisiert; das Über-Fenster liest seine Versionswerte jetzt aus dem Bundle. DMG-Layout aus dem veröffentlichten 0.1.1-Paket als feste Vorlage übernommen; Paketierung benötigt keine Finder-Automation mehr. Verifikation prüft auch diese Vorlage und das Hintergrundbild. Der neue Vorabcheck wurde mit absichtlich fehlender Vorlage erfolgreich negativ getestet.
- Unabhängige statische Patchprüfung ohne blockierenden Befund. Modell-/Renderer-Test erfolgreich. Der erneute native Fokus-Test scheiterte einmal an der kurzen Fokusübergabe; die Ursache des ursprünglichen Fehllaufs ist nicht eindeutig belegt. Nach Ergänzung von Zustandsdiagnosen und Umstellung von direkten `resignKey()`-Aufrufen auf echte native Fensterübergaben erfolgreich; Produktionslogik dafür nicht verändert, Anforderungen nicht abgeschwächt. Nutzer arbeitet parallel am Rechner: künftige GUI-Fokustests vorher ankündigen und ein ruhiges Testfenster abstimmen; Build/Signierung/Git benötigen keinen exklusiven Zugriff.
- Die automatische Freigabeprüfung hielt die Apple-Einreichung zunächst vor Ausführung an; nach ausdrücklicher Nutzerbestätigung für App-ZIP und DMG an Apple war der vollständige Ablauf erfolgreich. Kein Clean-Machine-Start und keine zusätzliche physische Mehrdisplay-/Ruhezustands-Abnahme des Release-Artefakts. Die laufende lokale Test-App wurde für die Veröffentlichung nicht erneut beendet oder ersetzt.

## Aufnahmeblockade und Härtung der Auswahl (8. Oktober 2026)

- Installierte App `/Applications/R3Dshot.app`, Version/Build `0.1.1/2`, unter macOS 27.0.1 (`26A434`): Menü und Prozess liefen, aber Aufnahmebefehle zeigten keine sichtbare Auswahl. Ein C49RG9x-Hauptdisplay mit 5120 × 1440 war angeschlossen.
- Live-Diagnose: Menüaktionen wurden zugestellt, TCC erlaubte Bildschirmaufnahme, strikte Codesign-Prüfung und Gatekeeper waren erfolgreich. Der Hauptthread wartete regulär auf Ereignisse. Weitere Aufnahmebefehle wurden mit `Ignoring a capture command while another capture is active` verworfen.
- Nutzer öffnete und schloss die Einstellungen; danach funktionierten Aufnahmen wieder. Selbst ein vorheriger Neustart der Anwendung hatte laut Nutzer nicht geholfen. Das Protokoll bestätigte `Capture selection cancelled` und anschließend `Capture completed`. Damit ist die festhängende Auswahl bestätigt; der genaue ursprüngliche Auslöser des Fokusproblems ist noch nicht reproduziert.
- Korrektur in `SelectionOverlayController.swift` und `CaptureCoordinator.swift`: nichtaktivierende Auswahlpanels mit explizitem Tastaturfokus, `hidesOnDeactivate = false`, exakter Bildschirmgeometrie und Escape-Responder; neue Aufnahmebefehle ersetzen eine unfertige Auswahl. Laufende Berechtigungs-/ScreenCaptureKit-Aufgaben bleiben serialisiert. Zusätzliche Logs enthalten nur Auswahl-/Fokuszustände.
- Härtung: begrenzter Fokus-Wiederholungsversuch beim Start, Freigabe des Aufnahmezustands bei fehlendem Startfokus, entprellter Abbruch bei echtem Fokusverlust sowie Abbruch bei Bildschirm-/Space-/Ruhezustands-/Sitzungswechsel. Eine UUID pro Auswahl schützt neue Auswahlen vor verspäteten Tasks, Observern und Eingaben alter Fenster. Kein wiederholtes Zurückholen des Fokus gegen andere Apps.
- `./script/test_selection_overlay.sh` testet den echten AppKit-Controller in einer grafischen Sitzung. Erfolgreich: erste Auswahl ohne Einstellungen, Panelgeometrie/-konfiguration, kurzer und echter Fokusverlust, fehlgeschlagener Startfokus, Ersatz einer Auswahl bei ausstehender Fokusprüfung, alte Escape-/Observer-Ereignisse, sechs Unterbrechungsmeldungen und vollständiger Abbau. Ein dabei entdeckter NSPanel-Initializer-Absturz aus dem ersten Entwurf wurde korrigiert. Der Sandboxlauf ohne Bildschirmzugriff ist kein gültiger Laufzeittest; der unveränderte Lauf in der GUI-Sitzung war erfolgreich.
- `./script/test_editor_model.sh` und `git diff --check` erfolgreich. Optimierter Release-Konfigurationsbuild unter `build/FocusRecoveryBuild/Build/Products/Release/R3Dshot.app` erfolgreich, mit vorhandener G2-Developer-ID und Hardened Runtime signiert; strikte Signaturprüfung erfolgreich. Keine Quellcodewarnungen, nur übersprungene AppIntents-Metadatenextraktion. Binary-SHA-256: `e0d36212721bd18746c27e89b5ab390bb18354297c0963b700aba5f6c6ece273`.
- Nach bestätigtem regulärem Beenden durch den Nutzer wurde `/Applications/R3Dshot.app` am 8. Oktober lokal ersetzt und frisch gestartet. Installiertes Binary entspricht exakt dem geprüften SHA-256; strikte Signaturprüfung erfolgreich, Signatur-Anforderung identisch zur bisherigen App. Die Preferences-Datei ist per SHA-256 unverändert. Rückfallkopien: `build/focus-recovery.ADkIao/Original-R3Dshot-0.1.1.zip` und `/Applications/.r3dshot-focus-update.5jfcbv7c/Previous.app`.
- Lokaler Build mit Version/Build `0.1.1/2`, kein GitHub-Release, Push oder neue Notarisierung. Nutzerprüfung der ersten Aufnahme ohne Einstellungen sowie Escape/erneuter Aufnahme angefordert. Physische Mehrdisplay-Wechsel, tatsächlicher Ruhezustand/Space-Wechsel und weitere Menü-/Hotkey-Aufnahmen bleiben separat zu prüfen.

## macOS-27-Kompatibilitätsprüfung (15. September 2026)

- Geprüfter Quellstand: `3524842`, vor der Prüfung sauberer Arbeitsbaum. Keine App-Codeänderungen erforderlich oder vorgenommen.
- Tatsächliche Testumgebung: macOS 27.0 (`26A428`), Xcode 27.0 (`27A266a`), macOS-SDK 27.0, Apple Silicon.
- `./script/test_editor_model.sh`: erfolgreich, Ausgabe `Editor model/renderer smoke test passed`. Der erste Sandbox-Versuch scheiterte am nicht beschreibbaren Swift-Modulcache; unverändert außerhalb der Sandbox erfolgreich.
- `./script/build_and_run.sh --verify`: erfolgreich; Debug-App mit stabiler Apple-Development-Signatur gebaut, gestartet und Prozessprüfung bestanden. Build-Protokoll lokal unter `/tmp/r3dshot-macos27-build.log` (temporär).
- Keine Compilerfehler oder Quellcodewarnungen. Einziger `warning:`-Eintrag: App-Intents-Metadatenextraktion übersprungen, weil die App keine AppIntents-Abhängigkeit hat.
- `vtool -show-build` bestätigt im erzeugten arm64-Binary SDK 27.0 und unverändert Mindestversion 15.2. Die Mindestversion ist keine erneute Laufzeitabnahme auf macOS 15.2.
- `codesign --verify --deep --strict` außerhalb der Sandbox erfolgreich; der anfängliche Sandbox-Trust-Fehler war dort nicht reproduzierbar. Der Prozess der frisch gebauten App lief bei der Nachprüfung weiterhin.
- Codeprüfung: Aufnahmen verwenden ScreenCaptureKit (`SCShareableContent`, `SCScreenshotManager`); keine Verwendung von `CGWindowListCreateImage` oder `CGDisplayCreateImage` gefunden. Globale Tastenkürzel verwenden weiterhin Carbon `RegisterEventHotKey`; der erfolgreiche Build belegt dessen SDK-Verfügbarkeit, nicht die tatsächliche Tastenzustellung. Berechtigungen und Fenster-Lifecycle benötigen weiterhin Laufzeitabnahme.
- Automatischer UI-Zugriff auf die frisch gebaute App lief in einen Timeout; keine automatisierte UI-Abnahme erfolgt.
- Manuelle Nutzerprüfung anschließend bestätigt: Aufnahme, Hotkeys und Editor wurden unter macOS 27 getestet, ohne festgestellte Auffälligkeiten.
- Ergebnis: Die macOS-27-Kompatibilitätsprüfung ist für den geprüften Umfang erfolgreich abgeschlossen: Build, Modell/Renderer, Prozessstart und Signatur technisch bestätigt; Aufnahme, Hotkeys und Editor durch den Nutzer bestätigt. Kein konkreter Anpassungsbedarf festgestellt. Einzelne Display-/Skalierungskombinationen, erstmalige Berechtigungsvergabe, Quick Actions, PNG-Export, Lifecycle-Sonderfälle und sämtliche Phase-7-Einzelinteraktionen wurden in der Rückmeldung nicht separat aufgeschlüsselt; daraus wird keine zusätzliche Detailabnahme abgeleitet.
- Kein Release erstellt; die veröffentlichte 0.1.0-App wurde in dieser Prüfung nicht separat auf macOS 27 getestet.

## Abgeschlossener G2-Release 0.1.1 — 2026-10-02

- [0.1.1](https://github.com/r3d42-git/R3Dshot/releases/tag/v0.1.1) veröffentlicht. Annotierter Tag `v0.1.1` bleibt auf Quellcommit `26f4624b64fc4975883ea7bd8253c608b9a78ab9`; Abschlussnachweise folgen separat.
- Vorhandener Modell-/Renderer-Test und native lokale sowie Download-Verifikation erfolgreich.
- Apple-Submission(s) `f404c87b-57e0-40b1-b29b-9ee50f01d317 / 070c4a97-8629-4b41-9ca8-e9b62603701a`: Accepted; angeheftetes App-Ticket im finalen Paket geprüft. Bei DMGs trägt auch der Container ein eigenes gültiges Ticket.
- Frischer GitHub-Download: SHA-256 `5fe4a46092003ab8efbff9dea36e7f0b4eae86bd5ce0188c800aec4aab16889d`, strikte Signatur, Bundle-Metadaten, Architektur, Stapling und Gatekeeper erfolgreich. Zusätzliche Leaf-Prüfung bestätigt exakt G2 `D548540E7FE1BD9B3C4518CC02D8786E1BFEB885`.
- Asset `R3Dshot-0.1.1-mac-arm64.dmg`, Version/Build `0.1.1/2`, Bundle-ID `org.r3d.R3Dshot`. Keine neue manuelle UI-Abnahme abgeleitet.

## Architekturdiagramme (6. September 2026)

- Auf Basis dieser Übergabe und des aktuellen Codes wurden mit Archify eine [Architekturübersicht](docs/diagrams/architektur.html) und der [Ablauf Aufnahme → Bearbeitung → Export](docs/diagrams/ablauf.html) mit deutschen Beschriftungen erstellt.
- [Quellen, Ablaufdetails und Prüfnachweise](docs/diagrams/README.md) stehen zusammen mit den bearbeitbaren JSON-Spezifikationen unter `docs/diagrams/`.
- Beide HTML-Artefakte bestehen alle neun Showcase-Prüfungen ohne Fehler oder Warnungen. Die Browserprüfung umfasst vier Desktopgrößen sowie Hell-/Dunkel-Screenshots; die Sichtprüfung ist separat dokumentiert.
- Die Diagramme berücksichtigen Abweichungen vom früheren Entwurf: Originalbild im Speicher, gemeinsamer Preview-/Export-Renderer, Displayaufnahme mit Zuschnitt für Ein-Display-Bereiche und direkte Rechteck-API als displayübergreifender Fallback.
- Die deutschen und englischen Projekt-READMEs verlinken die Diagramme; PNG-Vorschauen sind direkt auf GitHub in der Diagrammdokumentation sichtbar.
- Es wurde nur Dokumentation ergänzt; die bestehenden offenen manuellen App-Abnahmen bleiben unverändert.

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
