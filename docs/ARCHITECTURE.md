# R3Dshot – Architektur

**Status:** Phase 7 umgesetzt. Dieses Dokument hält die tragenden Architekturentscheidungen und die Grenzen des inzwischen vollständigen Editorpfads fest.

R3Dshot wird eine ausschließlich native, lokale macOS-Menüleisten-App für Apple Silicon und macOS 15.2 oder neuer. Sie verwendet keine externen Laufzeit-Abhängigkeiten. Die erste Fassung ist für direkte, signierte GitHub-Distribution vorgesehen und nicht für den Mac App Store sandboxed. Dadurch ist das Speichern in ~/Pictures/R3Dshot ohne unnötige Bookmark-Infrastruktur möglich. Ein späterer App-Store-Ableger wäre eine getrennte Erweiterung mit Security-Scoped Bookmarks.

## 1. Architekturüberblick

Die Komponenten kommunizieren über kleine fachliche Protokolle. UI ruft nicht direkt ScreenCaptureKit auf und der Renderer kennt weder Menü noch Dateidialog.

    NSStatusItem / globale Hotkeys
                  │ CaptureCommand
                  ▼
           CaptureCoordinator ───────────► PermissionService
                  │                              │
                  ▼                              ▼
      SelectionOverlayController       Screen Recording (TCC)
                  │ CaptureRequest
                  ▼
        ScreenCaptureService (ScreenCaptureKit)
                  │ CapturedScreenshot
                  ▼
          PendingCaptureStore ───► QuickActionPanel (nicht modal)
                  │
                  ├──► ScreenshotFileStore / NSSavePanel / NSPasteboard
                  └──► EditorWindowCoordinator
                                  │
                                  ▼
                    ScreenshotDocument + EditorStore
                                  │
                                  ▼
                     ScreenshotRenderer (Core Graphics/Core Image)

Die unveränderlichen Bilddaten, die Editordaten und die kurzfristige UI-Auswahl sind strikt getrennt:

- **CapturedScreenshot** ist ein unverändertes CGImage mit Aufnahme-Metadaten.
- **ScreenshotDocument** enthält eine Referenz darauf, Crop und Annotationen.
- **EditorStore** enthält zusätzlich flüchtige Zustände wie Auswahl, aktives Werkzeug und Zoom. Diese UI-Zustände werden nicht exportiert.

Phase 2 implementiert den Pfad bis zum Quick-Action-Panel. Phase 3 ergänzt darauf ein codierbares ScreenshotDocument, einen getrennten EditorStore und den gemeinsamen ScreenshotRenderer. Der erste vertikale Schnitt unterstützt Rechtecke vollständig von der Erstellung bis zum PNG-Export; weitere Elementtypen verwenden dieselben Grenzen.

## 2. Geplante Projektstruktur

Ein normales Xcode-macOS-App-Projekt ist passender als ein reines SwiftPM-Bundle: Asset Catalog, Info.plist, Code Signing, LSMinimumSystemVersion 15.2, Apple-Silicon-Architektur und spätere notarized Archives sind damit klar integriert. Die App bleibt frei von Drittcode.

    R3Dshot/
    ├── R3Dshot.xcodeproj/
    ├── R3Dshot/
    │   ├── App/                       # @main, Lebenszyklus, Fenster-Szenen
    │   ├── MenuBar/                   # NSStatusItem und dynamisches NSMenu
    │   ├── Capture/                   # Ablauf, SCKit, Auswahl-Overlays
    │   ├── Permissions/               # TCC-Status und Erklär-UI
    │   ├── QuickAction/               # modeless schwebendes Panel
    │   ├── Storage/                   # PNG, Namen, Clipboard, Save Panel
    │   ├── Shortcuts/                 # Carbon-Hotkeys und Recorder
    │   ├── Editor/
    │   │   ├── Document/              # persistierbares, nicht-destruktives Modell
    │   │   ├── Canvas/                # Vorschau, Hit Testing, Interaktion
    │   │   ├── Inspector/             # kontextuelle Eigenschaften
    │   │   └── Rendering/             # gleicher Preview-/Export-Renderer
    │   ├── Settings/                  # Settings Scene und Preferences
    │   ├── Shared/                    # kleine Werte, Fehler und Logger
    │   └── Resources/Assets.xcassets/ # App- und Menüleisten-Assets
    ├── R3DshotTests/
    ├── R3DshotUITests/
    ├── docs/
    │   ├── ARCHITECTURE.md
    │   └── DECISIONS.md
    ├── script/build_and_run.sh
    ├── .github/workflows/ci.yml
    ├── README.md
    ├── LICENSE
    └── .gitignore

Capture, QuickAction, Storage und Editor dürfen sich nur über fachliche Modelle kennen. Beispielsweise erhält QuickAction einen PendingCapture, aber nie einen SCStream oder ein Overlay-Window.

## 3. Datenmodell für Capture und nicht-destruktiven Editor

Der Canvas verwendet **Bildpixel** als kanonisches Koordinatensystem. Das macht PNG-Exporte bei Retina- und Nicht-Retina-Displays deterministisch. Auswahl-Overlays arbeiten in Display-Punkten; beim Capture wird einmalig über den displayScaleFactor in Pixel umgerechnet. Editor-Views skalieren diese Pixel nur für die Darstellung.

    struct CapturedScreenshot: Identifiable {
        let id: UUID
        let originalImage: CGImage              // nie überschreiben
        let pixelSize: PixelSize
        let capturedAt: Date
        let source: CaptureSource
    }

    enum CaptureSource {
        case area(screenRectInPoints: CGRect)
        case window(windowID: CGWindowID, includesShadow: Bool)
        case display(screenRectInPoints: CGRect)
    }

    struct ScreenshotDocument: Identifiable, Codable {
        let id: UUID
        let original: OriginalImageReference
        var crop: CropState
        var elements: [AnnotationElement]       // aufsteigend nach zIndex
        var formatVersion: Int
    }

OriginalImageReference verweist während der Arbeit auf eine private temporäre PNG-Datei und enthält Pixelgröße sowie Farbprofil. Das ist robuster als ein großer Data-Blob in UserDefaults. „Verwerfen“ entfernt nur diese temporäre Datei; der Bildinhalt wird niemals verändert.

### 3.1 Annotationen

Jedes sichtbare Bearbeitungselement hat eine stabile ID, Bounding Box, z-Reihenfolge, optionalen Drehwinkel und einen typisierten Payload. ColorValue ist ein eigener RGBA-Wert und nicht SwiftUI.Color, damit Dokumente und Zwischenablage UI-unabhängig codierbar bleiben.

    struct AnnotationElement: Identifiable, Codable {
        let id: UUID
        var zIndex: Int
        var transform: ElementTransform
        var payload: AnnotationPayload
    }

    enum AnnotationPayload: Codable {
        case rectangle(RectangleStyle)
        case ellipse(EllipseStyle)
        case arrow(ArrowStyle)
        case text(TextStyle)
        case speechBubble(SpeechBubbleStyle)
        case stepNumber(StepNumberStyle)
        case marker(StrokeStyle)
        case focus(FocusStyle)
        case pixelate(PixelateStyle)
        case redact(RedactionStyle)
    }

ElementTransform kapselt boundsInCanvasPixels, Rotation und spätere Ankerpunkte. Linien und Pfeile erhalten Start- und Endpunkt relativ zu ihren Bounds; Marker bestehen aus normierten Punktfolgen. Damit funktionieren Verschieben, Resize-Handles, Duplizieren und Z-Reihenfolge über dieselbe Editor-API.

Crop ist kein Annotationselement, sondern ein einzelner Dokumentzustand. Das verhindert Mehrdeutigkeit bei Effektbereichen und erlaubt Undo/Redo für Crop genau wie für ein Objekt.

### 3.2 Bearbeiten, Undo und Clipboard

EditorStore exponiert gezielte Methoden wie insert, replace, delete, duplicate, move, resize, bringForward und setCrop. Jede Methode erzeugt einen kleinen EditorCommand mit Vorher-/Nachher-Zustand des betroffenen Werts und registriert ihn bei UndoManager. Drag-Gesten werden zu einem Command zusammengefasst, nicht zu einem Eintrag pro Pixel.

Copy/Paste verwendet einen eigenen UTType, org.r3d.r3dshot.annotation-elements, mit codierten AnnotationElement-Fragmenten. Erst später kommt zusätzlich eine gerenderte PNG-Repräsentation hinzu; die editierbare Repräsentation bleibt vorrangig.

## 4. Benötigte Apple-Frameworks

| Bereich | Framework/API | Zweck |
| --- | --- | --- |
| App und Editor | SwiftUI, Observation | Szenen, Settings, Inspector und State |
| Menü, Panels, Dateien | AppKit | NSStatusItem, NSPanel, NSSavePanel, NSPasteboard, Fenster-Aktivierung |
| Aufnahme | ScreenCaptureKit | SCScreenshotManager für Bereich/Display; SCShareableContent und SCContentFilter für Fenster |
| Berechtigung | CoreGraphics | CGPreflightScreenCaptureAccess, CGRequestScreenCaptureAccess |
| Hotkeys | Carbon/HIToolbox | RegisterEventHotKey für globale virtuelle Keycodes |
| Login | ServiceManagement | SMAppService.mainApp |
| Bildverarbeitung | Core Graphics, Core Image, ImageIO, UniformTypeIdentifiers | Rendern, PNG und nicht-destruktive Blur-/Pixel-Effekte |
| Logging | OSLog | datensparsame technische Diagnose |

AppKit ist bewusst schmal eingesetzt. SwiftUI bildet die Hauptoberfläche; NSStatusItem mit NSMenu ist aber die verlässlichere native Schnittstelle für ein dynamisches Menü einschließlich Tastenkürzel-Spalte. Globale Hotkeys und Overlay-Panels sind ebenfalls klassische AppKit-/HIToolbox-Aufgaben.

## 5. Konzept der Menüleisten-App

Beim Start setzt der AppDelegate die Aktivierungsrichtlinie auf accessory. Es gibt kein WindowGroup als Startfenster. MenuBarController erstellt ein NSStatusItem mit Template-NSImage und ein natives NSMenu:

1. Bereich aufnehmen
2. Fenster aufnehmen
3. Bildschirm aufnehmen
4. Editor öffnen, deaktiviert solange kein Capture verfügbar ist
5. Einstellungen …
6. Über R3Dshot
7. R3Dshot beenden

Die drei Capture-Menüpunkte lesen Titel und Key-Equivalent-Anzeige aus demselben ShortcutStore wie der globale Registrierer. Nach jeder Änderung werden die drei NSMenuItem-Instanzen aktualisiert; Anzeige und tatsächlicher Hotkey können nicht auseinanderlaufen. Beim Öffnen von Editor oder Settings darf die App für die Dauer des sichtbaren Fensters zu regular wechseln, damit das Fenster wie eine normale macOS-Anwendung aktivierbar ist; beim Schließen kehrt sie zu accessory zurück. Dieses Verhalten wird in Phase 2 auf aktuellem macOS geprüft.

Das Quick-Action-Panel ist ein nicht-modales NSPanel ohne dauerhafte Dokumentbindung, dessen Inhalt aus SwiftUI kommt. PendingCaptureStore hält mehrere noch nicht verworfene Aufnahmen. Eine neue Aufnahme blockiert daher weder das vorige Panel noch den nächsten Shortcut.

## 6. Konzept für globale Shortcuts und Print

### Entscheidung

Für die globalen Auslöser verwenden wir Carbon RegisterEventHotKey, nicht einen globalen NSEvent-Monitor oder CGEventTap. Die API registriert einen virtuellen Keycode mit Modifikatoren beim System; sie verlangt keine Input-Monitoring- oder Accessibility-Berechtigung und R3Dshot muss keinen fremden Tastendruck mitschneiden. Die Schnittstelle ist in aktuellen Xcode-SDK-Headern weiterhin für globale virtuelle Keycodes vorhanden.

NSEvent dient ausschließlich im sichtbaren Settings-Shortcut-Recorder zum Erfassen einer neu gewünschten Taste. Die gespeicherte Form lautet:

    struct KeyboardShortcut: Codable, Hashable {
        let keyCode: UInt32
        let modifiers: ShortcutModifiers
        let displayName: String
    }

Die Standardbelegung nutzt kVK_F13 (0x69), die übliche macOS-Zuordnung für die auf vielen externen Tastaturen als Print oder PrtSc beschriftete Taste:

- F13 / Print: Bereich
- Option + F13 / Print: Fenster
- Control + F13 / Print: Bildschirm

Eine Hardwarebeschriftung ist allerdings nicht Teil des macOS-Ereignisses. Ein Keyboard-Treiber kann Print als F13, einen anderen virtuellen Keycode oder als nicht registrierbare Sondertaste melden. Print wird daher nicht über ein festes Zeichen wie „Print“ erkannt. Der Recorder speichert den tatsächlich eintreffenden virtuellen Keycode und ein „Shortcut testen“-Modus zeigt die gerade empfangene Kombination. Die UI verwendet eine bekannte Funktionstastenbezeichnung, etwa F13, oder die beim Aufzeichnen erhaltene Darstellung. So kann jeder angeschlossene Keyboardtyp konfiguriert werden, ohne eine Eingabeüberwachungs-Berechtigung zu fordern.

Systemreservierte Hotkeys oder von anderen Apps behandelte Kombinationen können nicht vorab vollständig erkannt werden. Nach Registrierung testet R3Dshot die eigene Registrierung, meldet offensichtliche Fehler und weist bei Konflikten auf eine andere Kombination hin. Die Einstellungen dürfen keine leere oder nur aus Modifikatoren bestehende Kombination speichern.

## 7. Konzept für ScreenCaptureKit und Capture-Abläufe

ScreenCaptureService ist ein actor; nur UI-Schritte laufen auf dem MainActor. Vor einem Auftrag prüft PermissionService mit CGPreflightScreenCaptureAccess den Zustand. Erst nach einer eindeutig vom Nutzer angeforderten Aufnahme ruft die App bei Bedarf CGRequestScreenCaptureAccess auf und erklärt anschließend, wie die Einstellung „Bildschirm- & Systemaudioaufnahme“ in macOS geöffnet wird. Der Zugriff wird nicht beim bloßen App-Start erzwungen. Apple weist außerdem darauf hin, dass ein Neustart nach erstmaliger Freigabe erforderlich sein kann; R3Dshot behandelt das als klaren, wiederholbaren Zustand statt als Capture-Fehler.

### Bereich

SelectionOverlayController legt je Display einen transparenten, nicht aktivierenden NSPanel über die sichtbaren Screens. Der Panel-Inhalt wird mit SwiftUI gezeichnet: Abdunklung, Auswahlrechteck, Pixelmaße und Escape-Abbruch. Die Panels teilen sich einen Auswahlzustand in globalen Bildschirm-Punkten. Damit kann ein Rechteck bei gleichen Skalierungsfaktoren auch über Displaygrenzen hinweg aufgezogen werden; bei gemischten Skalierungen wird die Vorschaugröße gegen das tatsächliche Capture-Ergebnis in Phase 2 geprüft.

Nach der Auswahl werden alle Panels aus der Window-Liste entfernt und der nächste Compositor-Durchlauf abgewartet. Erst dann ruft ScreenCaptureService SCScreenshotManager.captureImage(in:) mit dem globalen screenRectInPoints auf. Die API ist laut Apple displayunabhängig und unterstützt mehrere Displays. **Bereichsaufnahmen benötigen damit keinen SCDisplay, keinen SCContentFilter und kein sourceRect.**

### Fenster

SCShareableContent liefert die erfassbaren SCWindow-Objekte mit Frames und Window-IDs. Der Overlay-Controller ermittelt das sichtbare Fenster unter dem Cursor, hebt dessen Frame hervor und übergibt nach Klick das korrespondierende SCWindow. SCContentFilter.desktopIndependentWindow erfasst genau dieses Fenster. Die Einstellung „Fensterschatten aufnehmen“ steuert die dafür vorgesehene Shadow-Option der Screenshot-Konfiguration. Für die Treffer-Reihenfolge wird, falls nötig, die WindowServer-Reihenfolge anhand der IDs ergänzt; das Capture selbst bleibt ScreenCaptureKit-basiert.

### Bildschirm

Bei einem Display erfasst die App dessen Bildschirm-Frame unmittelbar über SCScreenshotManager.captureImage(in:). Bei mehreren Displays zeichnet der gleiche Overlay-Controller pro Display eine auswählbare Fläche; der Klick bestimmt den Bildschirm-Frame. Die Auswahl ist nicht vom Hauptdisplay abgeleitet und funktioniert damit bei verschiedenen Anordnungen und Skalierungsfaktoren. Auch die Bildschirmaufnahme braucht keinen Display-Content-Filter.

Die Fensteraufnahme behält ihre ScreenCaptureKit-Konfiguration für Schatten und Mauszeiger. Die direkte Rect-API für Bereich und Display besitzt dagegen keinen Konfigurationsparameter; ihr Cursor-Verhalten wird in Phase 2 auf realer Hardware geprüft und die Einstellung nur dann als vollständig umgesetzt markiert, wenn sie für alle drei Aufnahmearten eindeutig funktioniert. Phase 2 liefert SDR-PNGs. HDR-Ausgabe und deren Farbmanagement gehören bewusst zu einem späteren, separat testbaren Erweiterungsschritt.

## 8. Nicht-destruktives Rendering

Die einzige Exportfunktion erhält ScreenshotDocument und das unveränderte Originalbild. Sie erzeugt ein neues Bitmap und schreibt PNG erst als letzten Schritt:

1. Crop aus dem Originalbild in einen CGBitmapContext zeichnen.
2. Elemente in aufsteigender z-Reihenfolge rendern.
3. Vektorformen, Text und Marker mit Core Graphics zeichnen.
4. Pixelate und Focus in einem isolierten Offscreen-Pass mit Core Image berechnen, auf ihre Maske beschränken und in die aktuelle Komposition zurückzeichnen.
5. Redaction als deckende Vektorfüllung rendern.
6. Die Komposition über ImageIO als PNG schreiben oder in ein NSImage für die Zwischenablage überführen.

Der Preview-Canvas ruft denselben ScreenshotRenderer mit reduzierter Ausgabegröße auf. Dadurch sind Vorschau und Export gleichartig, während das Original unverändert bleibt. Ein Effektelement verarbeitet stets die bis zu seinem zIndex bestehende Komposition; damit hat Z-Reihenfolge auch bei Pixelierung und Focus eine eindeutige Bedeutung. Später gezeichnete Elemente bleiben unberührt.

## 9. Visuelle Identität

Das App-Icon wird nicht aus einem SF Symbol abgeleitet. Das Konzept ist ein eigenständiges, abgerundetes dunkles Quadrat mit präzisem offenem Aufnahmerahmen in warmem Korallrot und einem kleinen hellen „dritten“ Eckpunkt als Wiedererkennung von R3D. Die Mitte bleibt ruhig; damit funktioniert das Motiv auch bei 16 × 16 Pixeln ohne Kamera-Clipart oder fremde Marken.

In Phase 2 entsteht daraus ein Vektor-Master, der in alle erforderlichen AppIcon-Größen gerendert und im Asset Catalog hinterlegt wird. Das Menüleisten-Symbol ist bewusst davon getrennt: ein einfarbiger vereinfachter offener Rahmen mit Punkt, als Template-Image markiert. So folgt es automatisch heller und dunkler Menüleiste und bleibt klein lesbar. SF Symbols dürfen intern für Werkzeug- und Menüaktionen dienen, nicht als Ersatz für das App-Icon.

## 10. Technische Risiken und Gegenmaßnahmen

| Risiko | Einordnung | Gegenmaßnahme |
| --- | --- | --- |
| Keine Screen-Recording-Freigabe oder System verlangt Neustart | hoch, erwartbar | Zustandsmodell, Hilfsansicht, nie leere Aufnahme als Erfolg melden |
| Display-Positionen, Retina-Skalierung, Spaces | hoch | globalen Rect und Canvas-Pixel getrennt halten; Tests mit 1×/2× und mehreren Displays |
| Print sendet nicht F13 oder ist Sondertaste | hoch | virtuellen Keycode aufzeichnen, Testmodus, F13 nur als Default |
| Globale Shortcut-Kollisionen | mittel | Registrierung neu aufbauen, Fehler erklären, Alternative zulassen |
| Overlay im Capture sichtbar | mittel | alle Panels vor Aufnahme aus der Window-Liste entfernen, Compositor-Durchlauf abwarten und real prüfen |
| Mauszeiger-Einstellung bei direkter Rect-Aufnahme | mittel | reale Prüfung des API-Verhaltens; erst nach verifizierter Umsetzung als vollständig markieren |
| Fenster-Treffer bei überlappenden/geschützten Fenstern | mittel | WindowServer-Reihenfolge mit SCKit-Kandidaten abgleichen |
| Fokus-/Pixel-Effekte bei großen Bildern teuer | mittel | Vorschau skalieren, Export außerhalb MainActor, Core-Image-Masken |
| HDR und breite Farbprofile | mittel | Erstes Release klar SDR-PNG; später getrenntes Farbmanagement |
| Editor wird monolithisch | mittel | Dokument, Renderer, Canvas-Interaktion und Inspector getrennt |
| Login Item scheitert in unsignierten Builds | niedrig bis mittel | SMAppService-Status und Fehler zeigen; auf signiertem Bundle prüfen |

## 11. Verifikation in Phase 2

Die erste Iteration wird auf Apple Silicon und macOS 15.2 oder neuer gegen mindestens diese Fälle geprüft: frische Berechtigung, abgelehnte Berechtigung, eine Anzeige, zwei verschieden skalierte Anzeigen, Bereichsaufnahme mit direktem Rect, Bildschirmaufnahme mit direktem Rect, PNG speichern, Clipboard und alle drei Standard-Hotkeys. Zusätzlich werden Overlay-Abbau vor Aufnahme sowie das Cursor-Verhalten der direkten Rect-API auf realer Hardware geprüft. Ohne reale Berechtigungs- und Mehrmonitor-Prüfung gilt die Capture-Implementierung nur als gebaut, nicht als vollständig abgenommen.

## Primärquellen

- [Apple: ScreenCaptureKit – einmalige Bildaufnahme](https://developer.apple.com/documentation/screencapturekit/scscreenshotmanager)
- [Apple: erfassbare Displays und Fenster](https://developer.apple.com/documentation/screencapturekit/scshareablecontent)
- [Apple: Fensterfilter für eine einzelne Aufnahme](https://developer.apple.com/documentation/screencapturekit/sccontentfilter/init%28desktopindependentwindow%3A%29)
- [Apple: Screen-Recording-Zugriff prüfen](https://developer.apple.com/documentation/coregraphics/cgpreflightscreencaptureaccess%28%29) und [anfordern](https://developer.apple.com/documentation/coregraphics/cgrequestscreencaptureaccess%28%29)
- [Apple: SMAppService für moderne Login Items](https://developer.apple.com/documentation/servicemanagement/smappservice)
