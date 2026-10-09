# R3Dshot

R3Dshot ist ein natives Screenshot-Werkzeug für macOS mit Menüleisten-Workflow, globalen Tastenkürzeln und nicht-destruktiver Annotation.

English version: [README.en.md](README.en.md)

## Systemanforderungen

- Apple-Silicon-Mac
- macOS 15.2 oder neuer
- Xcode 26.6 oder neuer für lokale Entwicklung

### macOS 27 geprüft

Am 15. September 2026 wurde der aktuelle Quellstand unter macOS 27.0 auf Apple Silicon mit Xcode 27 und dem macOS-27-SDK erfolgreich gebaut und gestartet. Modell-/Renderer-Tests und Signaturprüfung bestanden; bei der manuellen Prüfung von Aufnahme, globalen Hotkeys und Editor wurden keine Auffälligkeiten festgestellt. Für den geprüften Umfang waren keine Codeanpassungen nötig.

Dieser Hinweis dokumentiert die Prüfung des aktuellen Quellstands; das bestehende Release 0.1.0 bleibt unverändert. Details zum Prüfumfang stehen in der [Projektübergabe](PROJECT_SUMMARY.md#macos-27-kompatibilitätsprüfung-15-september-2026).

## Aktueller Entwicklungsstand

Die umgesetzten Editorphasen umfassen die Menüleisten-App, konfigurierbare globale Auslöser, die Screen-Recording-Berechtigung sowie Bereichs-, Fenster- und Bildschirmaufnahme. Screenshots werden in unabhängigen Editorfenstern geöffnet und lassen sich als PNG sichern, in die Zwischenablage kopieren oder über die Quick Action weitergeben.

Der Editor arbeitet nicht-destruktiv. Rechtecke, Ellipsen, Pfeile, Marker, Schwärzungen, Texte, Sprechblasen, Schrittmarkierungen, Pixelation und Fokuseffekte lassen sich erstellen, auswählen, verschieben, skalieren oder anpassen, gestalten, duplizieren, anordnen und löschen. Außerdem stehen Zuschneiden, Undo/Redo, Zoom, Inspector und das Speichern bzw. Kopieren des gerenderten Ergebnisses bereit.

Die Dock-/Menüleisten-Lifecycle-Regression und die Sicherheitsabfrage für „Beenden“ sind behoben.

Die Werkzeuge stehen gruppiert links, die Eigenschaften rechts. Werkzeugvorgaben lassen sich vor dem Zeichnen einstellen. Der dunkle Modus verwendet abgestufte Blautöne einschließlich Titelleiste; die helle Darstellung bleibt verfügbar. Die Statuszeile bietet Anpassen und eine pixelgenaue 100-%-Ansicht sowie Rückmeldungen nach Sichern und Kopieren.

Dieser Arbeitsstand ergänzt den Editor um:

- Mehrfachauswahl: Mit Befehl-Klick können mehrere Objekte zur Auswahl hinzugefügt oder daraus entfernt werden. Die gemeinsame Auswahl lässt sich starr verschieben, löschen, kopieren, einsetzen, duplizieren und in der Ebene anordnen. Bei einer Auswahl aus ausschließlich Schrittmarkierungen lässt sich deren Form gemeinsam ändern.
- Schrittmarkierungen: Kreis, Quadrat und abgerundetes Quadrat stehen als Formvarianten bereit. Ihre Zahl wird optisch zentriert und skaliert beim Vergrößern oder Verkleinern automatisch mit dem Marker. Das Schritt-Werkzeug bleibt nach dem Platzieren aktiv, damit fortlaufende Nummern gesetzt werden können; ein Klick auf das Auswahlwerkzeug beendet diesen Modus. Die Startnummer wird vor dem ersten Platzieren gewählt, sodass eine Folge beispielsweise bei 5 beginnen kann.
- Zuschneiden: Neben dem freien Ausschnitt sind die optionalen Seitenverhältnisse 1:1, 16:9 und 4:3 verfügbar; sie gelten beim Aufziehen und beim Skalieren über die Griffe.

## Architektur und Ablauf

Die anhand des Codes erstellten Archify-Diagramme zeigen die [Architekturübersicht](docs/diagrams/architektur.html) und den [Ablauf Aufnahme → Bearbeitung → Export](docs/diagrams/ablauf.html). Die HTML-Dateien herunterladen und lokal im Browser öffnen.

[Vorschauen, Codebelege und Prüfnachweise](docs/diagrams/README.md) sowie die bearbeitbaren JSON-Quellen liegen im Projekt unter `docs/diagrams/`.

## Lokal bauen und starten

    ./script/build_and_run.sh

Die optionalen Modi `--verify`, `--logs`, `--telemetry` und `--debug` stehen für Prozessprüfung und Diagnose zur Verfügung.

Der reine Dokument-/Renderer-Smoke-Test läuft mit:

    ./script/test_editor_model.sh

Werkzeugvorgaben, Undo/Redo, Nummerierung, Zoom und Tastaturzuordnung prüfen:

    ./script/test_editor_workflow.sh

Eine separate Editor-Vorschau mit synthetischem Bild öffnen:

    ./script/preview_editor.sh

Fokus- und Abbruchverhalten der Aufnahmeauswahl lokal prüfen (benötigt eine angemeldete grafische macOS-Sitzung; zeigt kurz Auswahlfenster, erstellt keine Screenshots). Während des Tests nicht parallel mit Maus/Tastatur arbeiten; bei gemeinsam genutztem Rechner das kurze Testfenster vorher ankündigen und abstimmen:

    ./script/test_selection_overlay.sh

Sofern im lokalen Schlüsselbund eine Apple-Development-Identität vorhanden ist, verwendet `build_and_run.sh` sie automatisch. Damit bleibt die macOS-Freigabe für Bildschirmaufnahme bei späteren Debug-Builds erhalten. Eine abweichende lokale Identität kann über `R3DSHOT_CODE_SIGN_IDENTITY` gewählt werden.

## Lizenz

R3Dshot wird unter GPL-3.0-or-later veröffentlicht. Der vollständige Lizenztext steht in [LICENSE](LICENSE).
