//
//  MenuBarController.swift
//  R3Dshot
//

import AppKit

/// AppKit's narrow menu-bar bridge. SwiftUI remains responsible for the
/// Settings, editor and quick-action windows; this class only sends events to
/// the app coordinator through its closures.
@MainActor
final class MenuBarController: NSObject {
    var onCaptureRequested: ((CaptureAction) -> Void)?
    var onEditorRequested: (() -> Void)?
    var onSettingsRequested: (() -> Void)?
    var onAboutRequested: (() -> Void)?
    var onQuitRequested: (() -> Void)?

    var isEditorAvailable = false {
        didSet {
            updateEditorItem()
        }
    }

    private let shortcutStore: ShortcutStore
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let editorItem = NSMenuItem()
    private var shortcutStoreObserver: UUID?

    init(shortcutStore: ShortcutStore) {
        self.shortcutStore = shortcutStore
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        configureStatusItem()
        configureMenu()
        shortcutStoreObserver = shortcutStore.observeChanges { [weak self] _, _ in
            self?.refreshShortcutCaptions()
        }
    }

    /// Removes the imperative observer before the controller leaves the app's
    /// main-actor lifecycle. The weak callback makes deallocation safe even
    /// when this is not needed by the application's long-lived controller.
    func invalidate() {
        if let shortcutStoreObserver {
            shortcutStore.removeObserver(shortcutStoreObserver)
            self.shortcutStoreObserver = nil
        }
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func refreshShortcutCaptions() {
        for item in menu.items {
            guard let action = CaptureAction(menuItemTag: item.tag) else {
                continue
            }

            item.title = "\(action.menuTitle)\t\(shortcutStore.displayString(for: action))"
            item.toolTip = "\(action.menuTitle) (\(shortcutStore.displayString(for: action)))"
        }
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        let image = NSImage(named: NSImage.Name("MenuBarCaptureSymbol"))
            ?? NSImage(
                systemSymbolName: "viewfinder",
                accessibilityDescription: "R3Dshot"
            )
        image?.isTemplate = true

        button.image = image
        button.imagePosition = .imageOnly
        button.toolTip = "R3Dshot"
    }

    private func configureMenu() {
        menu.autoenablesItems = false

        for action in CaptureAction.allCases {
            let item = NSMenuItem(
                title: action.menuTitle,
                action: #selector(requestCapture(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = action.menuItemTag
            menu.addItem(item)
        }

        menu.addItem(.separator())

        editorItem.title = "Editor öffnen"
        editorItem.action = #selector(requestEditor(_:))
        editorItem.target = self
        menu.addItem(editorItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Einstellungen …",
            action: #selector(requestSettings(_:)),
            keyEquivalent: ","
        )
        settingsItem.keyEquivalentModifierMask = .command
        settingsItem.target = self
        menu.addItem(settingsItem)

        let aboutItem = NSMenuItem(
            title: "Über R3Dshot",
            action: #selector(requestAbout(_:)),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "R3Dshot beenden",
            action: #selector(requestQuit(_:)),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = .command
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        refreshShortcutCaptions()
        updateEditorItem()
    }

    private func updateEditorItem() {
        editorItem.isEnabled = isEditorAvailable
    }

    @objc private func requestCapture(_ sender: Any?) {
        guard
            let item = sender as? NSMenuItem,
            let action = CaptureAction(menuItemTag: item.tag)
        else {
            return
        }

        onCaptureRequested?(action)
    }

    @objc private func requestEditor(_ sender: Any?) {
        onEditorRequested?()
    }

    @objc private func requestSettings(_ sender: Any?) {
        onSettingsRequested?()
    }

    @objc private func requestAbout(_ sender: Any?) {
        onAboutRequested?()
    }

    @objc private func requestQuit(_ sender: Any?) {
        if let onQuitRequested {
            onQuitRequested()
        } else {
            NSApp.terminate(nil)
        }
    }
}
