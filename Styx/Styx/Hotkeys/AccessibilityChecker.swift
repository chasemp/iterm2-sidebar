import ApplicationServices

enum AccessibilityChecker {
    /// Whether the app has Accessibility permission (needed for global hotkeys).
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Prompt the user to grant Accessibility access if not already trusted.
    /// Shows the macOS system dialog.
    static func promptIfNeeded() {
        if !isTrusted {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
    }
}
