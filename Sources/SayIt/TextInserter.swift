import AppKit
import Carbon.HIToolbox

/// Inserts text at the cursor of the frontmost app via a clipboard swap +
/// synthesized ⌘V, then restores the previous clipboard contents.
@MainActor
final class TextInserter {
    enum InsertError: Error {
        case secureInput
    }

    private static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

    func insert(_ text: String) throws {
        let pasteboard = NSPasteboard.general

        if IsSecureEventInputEnabled() {
            // Password fields block synthetic keystrokes. Leave the text on
            // the clipboard so the user can paste manually if they want.
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            throw InsertError.secureInput
        }

        let saved: [NSPasteboardItem] = (pasteboard.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        }

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        // Hint clipboard managers not to record this transient write.
        pasteboard.setString("", forType: Self.transientType)

        // A short beat lets the target app observe the new clipboard.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            Self.postCommandV()
        }

        // Restore whatever was on the clipboard before.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            pasteboard.clearContents()
            if !saved.isEmpty {
                pasteboard.writeObjects(saved)
            }
        }
    }

    private static func postCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
