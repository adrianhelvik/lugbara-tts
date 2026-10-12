import Carbon
import Foundation

/// Global keyboard shortcuts. They work without Accessibility permission.
enum Hotkey {
    private static var actions: [UInt32: () -> Void] = [:]
    private static var refs: [EventHotKeyRef] = []
    private static var handlerInstalled = false

    /// ⌥⎋ (Option+Esc).
    static let option = UInt32(optionKey)
    /// ⌥⇧⎋ (Option+Shift+Esc).
    static let optionShift = UInt32(optionKey | shiftKey)

    /// Registers Esc with `modifiers`. Returns false when another app already uses the combination.
    @discardableResult
    static func registerEscape(modifiers: UInt32, _ action: @escaping () -> Void) -> Bool {
        installHandler()
        let id = UInt32(actions.count + 1)
        actions[id] = action
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(kVK_Escape), modifiers,
                                         EventHotKeyID(signature: OSType(0x4C47_4252), id: id), // "LGBR"
                                         GetApplicationEventTarget(), 0, &ref)
        if let ref { refs.append(ref) }
        return status == noErr
    }

    private static func installHandler() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            let id = hotKeyID.id
            DispatchQueue.main.async { Hotkey.actions[id]?() }
            return noErr
        }, 1, &eventType, nil, nil)
    }
}
