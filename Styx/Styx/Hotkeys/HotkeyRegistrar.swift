import Carbon
import Foundation

@MainActor
final class HotkeyRegistrar {
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var handlers: [UInt32: () -> Void] = [:]
    private var nextId: UInt32 = 1
    private var carbonHandlerInstalled = false

    var registeredCount: Int { handlers.count }

    func register(_ combo: ParsedKeyCombo, handler: @escaping () -> Void) {
        guard let keyCode = HotkeyParser.carbonKeyCode(for: combo.keyString) else { return }
        let mods = HotkeyParser.carbonModifiers(for: combo.modifiers)

        if !carbonHandlerInstalled {
            installCarbonHandler()
            carbonHandlerInstalled = true
        }

        let id = nextId
        nextId += 1
        handlers[id] = handler

        let hotKeyId = EventHotKeyID(signature: fourCC("STYX"), id: id)
        var ref: EventHotKeyRef?
        RegisterEventHotKey(keyCode, mods, hotKeyId, GetEventDispatcherTarget(), 0, &ref)
        if let ref { hotKeyRefs.append(ref) }
    }

    func unregisterAll() {
        for ref in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        handlers.removeAll()
        nextId = 1
    }

    private func installCarbonHandler() {
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let this = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, userData -> OSStatus in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                var hotKeyId = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyId
                )
                let registrar = Unmanaged<HotkeyRegistrar>.fromOpaque(userData).takeUnretainedValue()
                if let handler = registrar.handlers[hotKeyId.id] {
                    DispatchQueue.main.async { handler() }
                }
                return noErr
            },
            1,
            &eventSpec,
            this,
            nil
        )
    }

    private func fourCC(_ str: String) -> OSType {
        var result: OSType = 0
        for char in str.utf8.prefix(4) { result = (result << 8) | OSType(char) }
        return result
    }
}
