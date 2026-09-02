//
//  GlobalHotKeyManager.swift
//  R3Dshot
//

import Carbon
import Foundation

/// Registers the three capture shortcuts with Carbon. This is deliberately not
/// an event tap, so R3Dshot does not observe unrelated keystrokes and does not
/// need Input Monitoring or Accessibility permission.
@MainActor
final class GlobalHotKeyManager {
    enum RegistrationState: Equatable {
        case inactive
        case registered
        case duplicate(of: CaptureAction)
        case failed(OSStatus)
    }

    /// Called on the main actor after the system delivers a registered shortcut.
    var onCaptureAction: ((CaptureAction) -> Void)?

    /// Called after a refresh if a shortcut could not be registered.
    var onRegistrationStateChange: ((CaptureAction, RegistrationState) -> Void)?

    private static let hotKeySignature: OSType = 0x52334453 // "R3DS"

    private let shortcutStore: ShortcutStore
    private var shortcutStoreObserver: UUID?
    private var eventHandler: EventHandlerRef?
    private var hotKeyReferences: [CaptureAction: EventHotKeyRef] = [:]
    private var isShortcutRecordingActive = false

    private(set) var registrationStates: [CaptureAction: RegistrationState] = [:]
    private(set) var isRunning = false

    init(shortcutStore: ShortcutStore) {
        self.shortcutStore = shortcutStore

        shortcutStoreObserver = shortcutStore.observeChanges { [weak self] _, _ in
            self?.refreshRegistrations()
        }
    }

    /// Ends registration and removes the Store observer. Call from the app
    /// lifecycle before releasing this object.
    func invalidate() {
        if let shortcutStoreObserver {
            shortcutStore.removeObserver(shortcutStoreObserver)
            self.shortcutStoreObserver = nil
        }
        stop()
    }

    /// Starts listening. Calling this more than once is harmless.
    func start() {
        guard !isRunning else {
            return
        }

        guard installEventHandler() else {
            return
        }

        isRunning = true
        refreshRegistrations()
    }

    func stop() {
        unregisterAllHotKeys()

        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }

        isRunning = false
        updateRegistrationStates(with: Dictionary(uniqueKeysWithValues: CaptureAction.allCases.map { ($0, .inactive) }))
    }

    func registrationState(for action: CaptureAction) -> RegistrationState {
        registrationStates[action] ?? .inactive
    }

    /// The Carbon API handles a registered key before an AppKit view receives
    /// its `keyDown` event. Temporarily removing registrations lets the native
    /// shortcut recorder receive an existing shortcut such as Print/F13.
    func setShortcutRecordingActive(_ isActive: Bool) {
        guard isShortcutRecordingActive != isActive else {
            return
        }

        isShortcutRecordingActive = isActive

        if isActive {
            unregisterAllHotKeys()
            updateRegistrationStates(with: Dictionary(
                uniqueKeysWithValues: CaptureAction.allCases.map { ($0, .inactive) }
            ))
        } else {
            refreshRegistrations()
        }
    }

    /// Re-registers all values atomically from the user's perspective: existing
    /// registrations are removed before the new set is installed.
    func refreshRegistrations() {
        guard isRunning, !isShortcutRecordingActive else {
            return
        }

        unregisterAllHotKeys()

        var updatedStates: [CaptureAction: RegistrationState] = [:]
        var firstActionForShortcut: [KeyboardShortcut: CaptureAction] = [:]

        for action in CaptureAction.allCases {
            let shortcut = shortcutStore.shortcut(for: action)

            if let firstAction = firstActionForShortcut[shortcut] {
                updatedStates[action] = .duplicate(of: firstAction)
                continue
            }

            firstActionForShortcut[shortcut] = action
            updatedStates[action] = register(shortcut, for: action)
        }

        updateRegistrationStates(with: updatedStates)
    }

    private func installEventHandler() -> Bool {
        guard eventHandler == nil else {
            return true
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        var installedHandler: EventHandlerRef?
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            Self.eventHandlerCallback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &installedHandler
        )

        guard status == noErr, let installedHandler else {
            let states = Dictionary(uniqueKeysWithValues: CaptureAction.allCases.map { ($0, RegistrationState.failed(status)) })
            updateRegistrationStates(with: states)
            return false
        }

        eventHandler = installedHandler
        return true
    }

    private func register(_ shortcut: KeyboardShortcut, for action: CaptureAction) -> RegistrationState {
        var identifier = EventHotKeyID()
        identifier.signature = Self.hotKeySignature
        identifier.id = action.hotKeyID

        var hotKeyReference: EventHotKeyRef?
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers.rawValue,
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKeyReference
        )

        guard status == noErr, let hotKeyReference else {
            return .failed(status)
        }

        hotKeyReferences[action] = hotKeyReference
        return .registered
    }

    private func unregisterAllHotKeys() {
        for hotKeyReference in hotKeyReferences.values {
            UnregisterEventHotKey(hotKeyReference)
        }
        hotKeyReferences.removeAll()
    }

    private func updateRegistrationStates(with newStates: [CaptureAction: RegistrationState]) {
        for action in CaptureAction.allCases where registrationStates[action] != newStates[action] {
            let state = newStates[action] ?? .inactive
            registrationStates[action] = state
            onRegistrationStateChange?(action, state)
        }
    }

    private func receiveHotKey(id: EventHotKeyID) {
        guard id.signature == Self.hotKeySignature, let action = CaptureAction(hotKeyID: id.id) else {
            return
        }

        onCaptureAction?(action)
    }

    private static let eventHandlerCallback: EventHandlerUPP = { _, event, userData in
        guard let event, let userData else {
            return OSStatus(eventNotHandledErr)
        }

        var identifier = EventHotKeyID()
        let parameterStatus = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &identifier
        )

        guard parameterStatus == noErr else {
            return parameterStatus
        }

        let manager = Unmanaged<GlobalHotKeyManager>.fromOpaque(userData).takeUnretainedValue()
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                manager.receiveHotKey(id: identifier)
            }
        } else {
            Task { @MainActor [weak manager] in
                manager?.receiveHotKey(id: identifier)
            }
        }

        return noErr
    }
}
