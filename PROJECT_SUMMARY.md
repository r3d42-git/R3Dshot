# R3Dshot – Projektübergabe

Stand: 2. September 2026

## Als Nächstes zwingend zuerst

Vor weiteren Editorwerkzeugen wird die App-Lifecycle-Regression behoben.

### 1. Dock-Zustand beim Einstellungsfenster wiederherstellen

Aktueller Fehler: Beim Öffnen der Einstellungen erscheint R3Dshot als reguläre Dock-App. Nach dem Schließen des Einstellungsfensters bleibt das Dock-Symbol bestehen.

Wiederherzustellender Zielzustand:

- Einstellungen öffnen sich sofort als sichtbares Fenster.
- Allein das Einstellungsfenster aktiviert kein dauerhaftes Dock-Symbol.
- Nach dem Schließen der Einstellungen läuft R3Dshot ausschließlich als Menüleisten-App weiter.
- Ein Dock-Symbol erscheint nur, solange mindestens ein Editorfenster geöffnet ist.
- Nach dem letzten Editorfenster kehrt die App zuverlässig in den reinen Menüleistenmodus zurück.

### 2. Sicherheitsabfrage beim Beenden

„Beenden“ und Command-Q dürfen R3Dshot nicht mehr ohne Rückfrage vollständig schließen.

Die Abfrage soll verständlich anbieten:

- **In Menüleiste behalten** – bevorzugte Standardaktion; R3Dshot läuft ohne aktive Dock-App weiter.
- **R3Dshot beenden** – beendet die Anwendung vollständig.
- **Abbrechen** – lässt den aktuellen Zustand unverändert.

Offene Editorfenster mit ungesicherten Änderungen müssen weiterhin ihre vorhandene Sicherungsabfrage erhalten; keine Auswahl der neuen Beenden-Abfrage darf Änderungen stillschweigend verwerfen.

## Bestätigter Stand

- Bereichs-, Fenster- und Bildschirmaufnahme funktionieren.
- Das native Fadenkreuz der Bereichsauswahl funktioniert.
- Rechteck, Ellipse, Pfeil/Linie, Schwärzung und Marker funktionieren im Editor.
- Der Marker unterstützt Freihandzeichnen und automatisches horizontales Einrasten.
- Modell-/Renderer-Smoke-Test und signierter lokaler Build waren nach der letzten Änderung erfolgreich.

## Lokale Prüfung

```sh
./script/test_editor_model.sh
./script/build_and_run.sh --verify
```

Test-App:

`/Volumes/Media/codex/R3Dshot/build/DerivedData/Build/Products/Debug/R3Dshot.app`

