import AppKit

/// A small dialog where the user pastes their OpenAI API key.
@MainActor
enum APIKeyPrompt {
    static func show() {
        let alert = NSAlert()
        alert.messageText = "OpenAI API key"
        alert.informativeText = "Paste a key from platform.openai.com/api-keys. It is stored in your login keychain."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        let hasKey = Keychain.readAPIKey() != nil
        if hasKey { alert.addButton(withTitle: "Remove key") }

        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.placeholderString = hasKey ? "A key is saved. Paste a new one to replace it." : "sk-…"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        NSApp.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            let key = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { return }
            if Keychain.saveAPIKey(key) {
                Speaker.shared.hasAPIKey = true
                Speaker.shared.lastError = nil
            } else {
                Speaker.shared.lastError = "Could not save the key to the keychain."
            }
        case .alertThirdButtonReturn:
            Keychain.deleteAPIKey()
            Speaker.shared.hasAPIKey = false
        default:
            break
        }
    }
}
