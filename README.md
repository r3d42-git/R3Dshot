# R3Dshot

R3Dshot ist ein natives Screenshot-Werkzeug für macOS mit Menüleisten-Workflow, globalen Tastenkürzeln und nicht-destruktiver Annotation.

## Systemanforderungen

- Apple-Silicon-Mac
- macOS 15.2 oder neuer
- Xcode 26.6 oder neuer für lokale Entwicklung

## Aktueller Entwicklungsstand

Phase 2 ist umgesetzt und Phase 3 hat begonnen. Der lauffähige Build umfasst die Menüleisten-App, konfigurierbare globale Auslöser, Screen-Recording-Berechtigung, Bereichs-, Fenster- und Bildschirmaufnahme sowie PNG-, Zwischenablage- und Quick-Action-Workflow.

Der Editor ist ebenfalls nutzbar: Screenshots werden in normalen, unabhängigen Editorfenstern geöffnet; Rechtecke, Ellipsen, Pfeile, Marker und Schwärzungen lassen sich nicht-destruktiv erstellen, auswählen, verschieben, skalieren bzw. über ihre Endpunkte anpassen, gestalten, duplizieren, anordnen und löschen. Undo/Redo, Zoom, Inspector sowie das Speichern und Kopieren des gerenderten Ergebnisses sind verbunden. Weitere Werkzeuge folgen schrittweise auf derselben Dokument- und Renderer-Basis.

Die verbindliche nächste Aufgabe ist in [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) festgehalten: Zuerst wird die Dock-/Menüleisten-Lifecycle-Regression behoben und eine Sicherheitsabfrage für „Beenden“ ergänzt; erst danach folgen weitere Werkzeuge.

## Lokal bauen und starten

    ./script/build_and_run.sh

Die optionalen Modi --verify, --logs, --telemetry und --debug stehen für Prozessprüfung und Diagnose zur Verfügung.

Der reine Dokument-/Renderer-Smoke-Test läuft mit:

    ./script/test_editor_model.sh

Sofern im lokalen Schlüsselbund eine Apple-Development-Identität vorhanden ist, verwendet das Skript sie automatisch. Damit bleibt die macOS-Freigabe für Bildschirmaufnahme bei späteren Debug-Builds erhalten. Eine abweichende lokale Identität kann über `R3DSHOT_CODE_SIGN_IDENTITY` gewählt werden.

## Lizenz

R3Dshot wird unter GPL-3.0-or-later veröffentlicht. Der vollständige Lizenztext steht in [LICENSE](LICENSE).
