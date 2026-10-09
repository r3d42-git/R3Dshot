import AppKit
import SwiftUI

/// Isolated UI harness: no hotkeys, capture permissions, preferences or user files.
@main
struct EditorPreview {
    static func main() {
        let app = NSApplication.shared
        let delegate = PreviewDelegate()
        app.setActivationPolicy(.regular)
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class PreviewDelegate: NSObject, NSApplicationDelegate {
    private var window: EditorWindow!
    private var store: EditorStore!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let image = testImage()
        store = EditorStore(capture: PendingCapture(image: image, capturedAt: Date(), source: .area(screenRectInPoints: .zero)))
        let root = EditorView(store: store,
                              onSave: { [weak self] in self?.store.reportFeedback("Vorschau · Sichern") },
                              onSaveAs: { [weak self] in self?.store.reportFeedback("Vorschau · Sichern unter") },
                              onCopyRenderedImage: { [weak self] in self?.store.reportFeedback("Vorschau · Bild kopieren") })
        window = EditorWindow(contentViewController: NSHostingController(rootView: root))
        window.editorStore = store
        window.title = "R3Dshot – Editor-Vorschau"
        window.styleMask = [.titled,.closable,.miniaturizable,.resizable]
        window.toolbarStyle = .unified
        window.backgroundColor = EditorAppearance.titlebar
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 720,height: 480)
        window.setContentSize(NSSize(width: 1200,height: 760))
        window.center()
        configureMenu()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func configureMenu() {
        let bar = NSMenu()
        let appItem = NSMenuItem();bar.addItem(appItem)
        let appMenu = NSMenu();appItem.submenu = appMenu
        appMenu.addItem(withTitle: "Vorschau beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let editItem = NSMenuItem(title: "Bearbeiten", action: nil,keyEquivalent: "");bar.addItem(editItem)
        let editMenu = NSMenu(title: "Bearbeiten");editItem.submenu = editMenu
        editMenu.addItem(withTitle: "Kopieren",action: #selector(NSText.copy(_:)),keyEquivalent: "c")
        editMenu.addItem(withTitle: "Einsetzen",action: #selector(NSText.paste(_:)),keyEquivalent: "v")
        editMenu.addItem(withTitle: "Alles auswählen",action: #selector(NSText.selectAll(_:)),keyEquivalent: "a")
        let testItem=NSMenuItem(title:"Prüfansicht",action:nil,keyEquivalent:"");bar.addItem(testItem)
        let testMenu=NSMenu(title:"Prüfansicht");testItem.submenu=testMenu
        for (title,action) in [("Kleines Fenster",#selector(compact)),("Großes Fenster",#selector(large)),("Hell",#selector(light)),("Dunkel",#selector(dark))] {
            let item=NSMenuItem(title:title,action:action,keyEquivalent:"");item.target=self;testMenu.addItem(item)
        }
        NSApp.mainMenu=bar
    }
    @objc private func compact() { window.setFrame(NSRect(origin:window.frame.origin,size:NSSize(width:720,height:480)),display:true) }
    @objc private func large() { window.setContentSize(NSSize(width:1200,height:760)) }
    @objc private func light() { window.appearance=NSAppearance(named:.aqua) }
    @objc private func dark() { window.appearance=NSAppearance(named:.darkAqua) }

    private func testImage() -> CGImage {
        let width = 960, height = 600
        let context=CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:0,
                              space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(gray:0.97,alpha:1));context.fill(CGRect(x:0,y:0,width:width,height:height))
        NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(cgContext:context,flipped:false)
        let titleAttributes:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:32,weight:.semibold),.foregroundColor:NSColor(white:0.13,alpha:1)]
        ("Projektübersicht" as NSString).draw(at:CGPoint(x:55,y:490),withAttributes:titleAttributes)
        let attributes:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:22),.foregroundColor:NSColor(white:0.22,alpha:1)]
        ("Beispieldaten für die Editorprüfung" as NSString).draw(at:CGPoint(x:55,y:442),withAttributes:attributes)
        for (index,title) in ["Entwurf abstimmen","Rückmeldung sammeln","Ergebnis festhalten"].enumerated() {
            let y=CGFloat(325-index*95)
            context.setFillColor(CGColor(gray:0.88,alpha:1));context.fill(CGRect(x:55,y:y-18,width:850,height:1))
            (title as NSString).draw(at:CGPoint(x:55,y:y),withAttributes:attributes)
            (["Heute","Morgen","Freitag"][index] as NSString).draw(at:CGPoint(x:760,y:y),withAttributes:attributes)
        }
        NSGraphicsContext.restoreGraphicsState()
        return context.makeImage()!
    }
}
