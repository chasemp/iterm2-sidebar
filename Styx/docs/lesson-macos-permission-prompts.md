# Managing macOS Permission Prompts in Swift Apps with Test Suites

## The Problem

macOS apps that use system-level APIs — global hotkeys, screen recording, camera access, AppleScript automation — need explicit user permission. The OS shows a modal dialog the first time the app requests each permission. This is correct behavior at runtime.

The problem emerges when you have a test suite. XCTest bundles are hosted by your app binary. When Xcode runs your tests, it launches your app as the host process, which means `applicationDidFinishLaunching` fires before any test code runs. If that method contains permission requests, the system dialog appears on every test run. Run your suite 20 times during development and you've dismissed 20 accessibility prompts. Worse, some prompts (like Accessibility) require navigating to System Settings, which breaks your flow entirely.

This is not hypothetical. We hit it building Styx (an iTerm2 workspace manager) where `AXIsProcessTrustedWithOptions` was called in `applicationDidFinishLaunching` to enable Carbon global hotkeys. Every test run triggered the Accessibility permission dialog.

## The Fix

Detect when your app is running as a test host and skip all permission-related code.

```swift
private var isRunningTests: Bool {
    NSClassFromString("XCTestCase") != nil
}

func applicationDidFinishLaunching(_ notification: Notification) {
    guard !isRunningTests else { return }

    NSApp.setActivationPolicy(.accessory)
    AccessibilityChecker.promptIfNeeded()

    Task { @MainActor in
        let bridge = ITerm2Bridge()
        await launch(bridge: bridge)
    }
}
```

The `NSClassFromString("XCTestCase")` check is reliable because XCTest is only loaded into the process when running tests. It requires no build flags, environment variables, or conditional compilation.

The `guard !isRunningTests else { return }` is aggressive — it skips the entire launch sequence. This is deliberate. Tests should call the testable `launch(bridge:)` method directly with a fake bridge, not rely on the real launch path. This gives tests full control over initialization order and dependency injection.

## What This Applies To

Any system API that shows a dialog or requires user interaction:

- **Accessibility**: `AXIsProcessTrustedWithOptions` — needed for global hotkeys via Carbon `RegisterEventHotKey`
- **Camera/Microphone**: `AVCaptureDevice.requestAccess(for:)` — needed for video/audio capture
- **Location**: `CLLocationManager.requestWhenInUseAuthorization()` — needed for location services
- **Automation/AppleEvents**: sending AppleScript commands or using `NSWorkspace.open` with certain URL schemes
- **Full Disk Access**: not directly requestable, but code that fails without it should degrade gracefully in tests
- **Notifications**: `UNUserNotificationCenter.requestAuthorization` — needed for push/local notifications

The pattern also applies to any code that assumes a real user session: registering global event handlers, modifying the Dock, creating `NSPanel` windows (which flash on screen during tests), or writing to shared system state.

## The Deeper Lesson: Testable Launch

The permission prompt problem is a symptom of a larger design issue: `applicationDidFinishLaunching` doing too much. If your entire app initialization lives in that one method, you can't test any of it without triggering all of it.

The fix is to separate "real launch" from "testable initialization":

```swift
// Called by applicationDidFinishLaunching at runtime
// Called directly by tests with injected dependencies
func launch(bridge: any BridgeService) async {
    await store.connectBridge(bridge)
    if store.sidebarVisible { sidebarController.show() }
    floatingManager.refresh()
    registerHotkeys()
    startPolling()
}
```

Tests call `launch(bridge: FakeBridge())` — no subprocess, no permission dialogs, no real iTerm2 needed. The `applicationDidFinishLaunching` method becomes a thin wrapper that creates real dependencies and calls `launch`.

This pattern — extracting a testable `launch` or `configure` method from the lifecycle callback — applies to every platform: `viewDidLoad` in UIKit, `onAppear` in SwiftUI, `main` in CLI tools, `onCreate` in Android. The lifecycle method is the integration point. The extracted method is the testable unit.

## Alternative Detection Methods

`NSClassFromString("XCTestCase")` is the simplest approach but not the only one:

- **`ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"]`** — set by Xcode when running tests. More explicit but tied to Xcode's test runner implementation.
- **`#if DEBUG` + launch argument** — pass `-testing` as a launch argument in the test scheme. Requires scheme configuration.
- **Compile-time flag** — `#if TESTING` with a custom build setting. Requires separate build configurations.

The class check is preferred because it works with any test runner, requires zero configuration, and is a single line of code.
