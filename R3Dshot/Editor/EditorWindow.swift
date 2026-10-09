import AppKit

/// Annotation shortcuts belong to this editor window. Text fields keep their
/// native responder-chain copy, paste, deletion and undo behavior.
final class EditorWindow: NSWindow {
    weak var editorStore: EditorStore?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard !(firstResponder is NSTextView), let editorStore,
              let action = EditorKeyboardAction.resolve(event) else {
            return super.performKeyEquivalent(with: event)
        }
        action.perform(on: editorStore)
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard !(firstResponder is NSTextView), let editorStore,
              let action = EditorKeyboardAction.resolve(event) else {
            super.keyDown(with: event)
            return
        }
        action.perform(on: editorStore)
    }
}

enum EditorKeyboardAction: Equatable {
    case copy, paste, undo, redo, delete, deselect

    static func resolve(_ event: NSEvent) -> Self? {
        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        if modifiers == .command {
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "c": return .copy
            case "v": return .paste
            case "z": return .undo
            default: return nil
            }
        }
        if modifiers == [.command, .shift], event.charactersIgnoringModifiers?.lowercased() == "z" {
            return .redo
        }
        if modifiers.isEmpty {
            if event.keyCode == 51 || event.keyCode == 117 { return .delete }
            if event.keyCode == 53 { return .deselect }
        }
        return nil
    }

    @MainActor
    func perform(on store: EditorStore) {
        switch self {
        case .copy: store.copySelection()
        case .paste: store.paste()
        case .undo: store.undoManager.undo()
        case .redo: store.undoManager.redo()
        case .delete: store.deleteSelection()
        case .deselect:
            store.clearSelection()
            store.selectTool(.select)
        }
    }
}
