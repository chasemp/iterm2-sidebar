import ApplicationServices

enum AccessibilityChecker {
    /// Whether the app has Accessibility permission (needed for global hotkeys).
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Log a warning if Accessibility access is missing (needed for global hotkeys).
    /// Does not show a system prompt — Debug builds get a new signature each time,
    /// causing macOS to re-prompt on every launch. Users should grant access manually
    /// via System Settings > Privacy & Security > Accessibility.
    static func promptIfNeeded() {
        // No-op: just check, never prompt. Hotkeys will silently fail without access.
    }
}
