# Architekturentscheidungen

Kurze, fortlaufende Entscheidungen. Änderungen ersetzen keine stillschweigend; sie ergänzen eine neue Entscheidung mit Begründung und Migrationshinweis.

## ADR-001: macOS 15.2 und Apple Silicon sind harte Untergrenzen

**Entscheidung:** Deployment Target 15.2; Build-Setting ARCHS = arm64.

**Begründung:** Das Projekt soll die direkte, displayübergreifende ScreenCaptureKit-Rechteckaufnahme als regulären Pfad verwenden und keinen macOS-15.0-Kompatibilitätspfad pflegen.

**Folge:** SCScreenshotManager.captureImage(in:) ist verfügbar und der reguläre Capture-Pfad benötigt für Bereich und Bildschirm keinen Display-Content-Filter.

## ADR-002: Xcode-App-Projekt ohne externe Laufzeit-Dependencies

**Entscheidung:** Ein einzelnes natives macOS-App-Target mit Swift, SwiftUI und Apple-Frameworks ist die Basis. Projektdatei und Asset Catalog werden von Xcode verwaltet.

**Begründung:** Das reduziert Build-, Asset-, Signing- und Release-Komplexität und passt zu einem späteren GitHub-/notarisierten Release.

**Folge:** Es gibt keine Paketabhängigkeiten für Hotkeys, Capture oder Annotationen.

## ADR-003: NSStatusItem für das Menü, SwiftUI für inhaltliche UI

**Entscheidung:** Der Statusleisten-Einstieg nutzt NSStatusItem und NSMenu. Settings, Quick Action und der spätere Editor verwenden SwiftUI.

**Begründung:** Das klassische AppKit-Menü gibt vollständige Kontrolle über natives Menüverhalten und dynamische Key-Equivalent-Anzeige. SwiftUI bleibt der Standard für Fensterinhalte.

## ADR-004: Carbon RegisterEventHotKey für globale Shortcuts

**Entscheidung:** Registrierte globale virtuelle Hotkeys statt Event Tap oder globalem Tastaturmonitor.

**Begründung:** Kein Mitschneiden fremder Eingaben, keine Input-Monitoring- oder Accessibility-Berechtigung, passend für drei diskrete Auslöser.

**Folge:** Print ist nicht hart kodiert. F13 ist der Default; der Recorder speichert den wirklich gemeldeten virtuellen Keycode.

## ADR-005: ScreenCaptureKit, nicht CGWindowListCreateImage

**Entscheidung:** Jede tatsächliche Aufnahme läuft über ScreenCaptureKit.

**Begründung:** Das ist die moderne Apple-Schnittstelle für Displays und Fenster, mit Berechtigung, Mauszeiger- und Schattensteuerung.

**Folge:** Bereichs- und Bildschirmaufnahme verwenden einen Display-Content-Filter mit einer expliziten SCStreamConfiguration. Das liefert nach dem Schließen des Auswahl-Overlays einen frischen, aktuellen Compositor-Frame; Bereiche werden daraus pixelgenau ausgeschnitten. Fensteraufnahme verwendet weiterhin einen unabhängigen Fenster-Content-Filter.

## ADR-006: Originalbild und Editorelemente bleiben getrennt

**Entscheidung:** Annotationen und Effekte werden als codierbare Werte über dem Originalbild gespeichert; nur Export rendert Pixel.

**Begründung:** Auswahl, Änderung, Z-Reihenfolge, Undo/Redo und editierbares Copy/Paste bleiben damit möglich.

**Folge:** Ein gemeinsamer Core-Graphics-/Core-Image-Renderer ist für Vorschau und PNG-Export die einzige Kompositionsstelle.

## ADR-007: Direktdistribution zunächst ohne App Sandbox

**Entscheidung:** Das erste GitHub-Release wird Developer-ID-signiert und notarisiert, aber nicht sandboxed.

**Begründung:** R3Dshot soll ohne künstliche Ordnerwahl nach ~/Pictures/R3Dshot schreiben können. Es fordert nur die TCC-Berechtigung für Bildschirmaufnahme an.

**Folge:** Eine spätere Mac-App-Store-Variante braucht eine separate Analyse für Security-Scoped Bookmarks und die dann geltenden Entitlements.

## ADR-008: Editorwerkzeuge werden als vollständige vertikale Schnitte ergänzt

**Entscheidung:** Phase 3 beginnt mit einem vollständig bearbeitbaren Rechteck statt mit vielen nur teilweise funktionsfähigen Werkzeugen.

**Begründung:** Das Rechteck prüft bereits alle grundlegenden Editorgrenzen: kanonische Pixelkoordinaten, Auswahl, Verschieben und Skalieren, Eigenschaften, Z-Reihenfolge, Undo/Redo, Zwischenablage sowie gemeinsamen Vorschau-/Export-Renderer.

**Folge:** Ellipse, Pfeil, Text und Effekte werden schrittweise auf dem verifizierten Dokument-, Store- und Rendererpfad ergänzt. Während mindestens ein Editorfenster offen ist, verhält sich R3Dshot als reguläre macOS-App mit Dock-Symbol; nach dem letzten Editorfenster kehrt sie zur Menüleisten-App zurück.
