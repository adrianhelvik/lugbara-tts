import Carbon
import Foundation

/// A global keyboard shortcut. Works without Accessibility permission.
enum Hotkey {
    private static var action: (() -> Void)?
    private static var hotKeyRef: EventHotKeyRef?

    /// Registers ⌥⎋ (Option+Esc). Returns false when another app already uses it.
    @discardableResult
    static func register(_ action: @escaping () -> Void) -> Bool {
        self.action = action
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { Hotkey.action?() }
            return noErr
        }, 1, &eventType, nil, nil)

        let id = EventHotKeyID(signature: OSType(0x4C47_4252), id: 1) // "LGBR"
        let status = RegisterEventHotKey(UInt32(kVK_Escape), UInt32(optionKey), id,
                                         GetApplicationEventTarget(), 0, &hotKeyRef)
        return status == noErr
    }
}
