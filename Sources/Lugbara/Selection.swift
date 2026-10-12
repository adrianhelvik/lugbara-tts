import AppKit
import ApplicationServices

/// Reads the text selected in the frontmost app.
@MainActor
enum Selection {
    static var hasAccessibilityPermission: Bool { AXIsProcessTrusted() }

    /// Shows the system dialog that sends the user to Accessibility settings.
    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func read() async -> String? {
        if let text = readViaAccessibility(), !text.isBlank { return text }
        if let text = await readViaCopy(), !text.isBlank { return text }
        return nil
    }

    /// Asks the focused element for its selected text. Native apps support this, many web and Electron apps do not.
    private static func readViaAccessibility() -> String? {
        let systemWide = AXUIElementCreateSystemWide()
        var focused: AnyObject?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let element = focused else { return nil }
        var selected: AnyObject?
        guard AXUIElementCopyAttributeValue(element as! AXUIElement, kAXSelectedTextAttribute as CFString, &selected) == .success
        else { return nil }
        return selected as? String
    }

    /// Presses ⌘C, reads the clipboard, then puts the old clipboard back.
    private static func readViaCopy() async -> String? {
        let pasteboard = NSPasteboard.general
        let saved = pasteboard.pasteboardItems?.map { item in
            item.types.compactMap { type in item.data(forType: type).map { (type, $0) } }
        } ?? []
        let changeCountBefore = pasteboard.changeCount

        pressCommandC()

        var copied: String?
        for _ in 0..<20 {
            try? await Task.sleep(for: .milliseconds(25))
            if pasteboard.changeCount != changeCountBefore {
                copied = pasteboard.string(forType: .string)
                break
            }
        }

        if pasteboard.changeCount != changeCountBefore {
            pasteboard.clearContents()
            pasteboard.writeObjects(saved.map { pairs in
                let item = NSPasteboardItem()
                for (type, data) in pairs { item.setData(data, forType: type) }
                return item
            })
        }
        return copied
    }

    private static func pressCommandC() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyC: CGKeyCode = 8
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyC, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyC, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}

private extension String {
    var isBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
