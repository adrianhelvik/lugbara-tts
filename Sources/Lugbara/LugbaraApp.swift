import AppKit
import SwiftUI

@main
struct LugbaraApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var speaker = Speaker.shared
    @StateObject private var animation = IconAnimation()

    var body: some Scene {
        MenuBarExtra {
            MenuPanel(speaker: speaker, reading: speaker.reading)
        } label: {
            Image(nsImage: MenuBarIcon.image(phase: animation.phase, alert: speaker.lastError != nil))
                .onChange(of: speaker.isSpeaking) { _, speaking in animation.setRunning(speaking) }
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = Self.editMenu()
        Speaker.shared.hasAPIKey = Keychain.readAPIKey() != nil
        let speed = UserDefaults.standard.double(forKey: Settings.speed)
        Speaker.shared.speed = speed > 0 ? Float(speed) : 1.0

        if !Hotkey.registerEscape(modifiers: Hotkey.option, { Speaker.shared.toggle() }) {
            Speaker.shared.lastError = "Could not register ⌥⎋. Another app uses it."
        }
        if !Hotkey.registerEscape(modifiers: Hotkey.optionShift, { Speaker.shared.back() }) {
            Speaker.shared.lastError = "Could not register ⌥⇧⎋. Another app uses it."
        }
        if !Selection.hasAccessibilityPermission {
            Selection.requestAccessibilityPermission()
        }
        if Keychain.readAPIKey() == nil {
            DispatchQueue.main.async { APIKeyPrompt.show() }
        }
    }

    /// The app shows no menu bar, but ⌘V and friends only reach text fields through an Edit menu.
    private static func editMenu() -> NSMenu {
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editItem.submenu = edit
        let main = NSMenu()
        main.addItem(editItem)
        return main
    }
}
