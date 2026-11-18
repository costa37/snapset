import AppKit
import SwiftUI

final class SnapSetDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var window: NSWindow?
    private var manager: WindowManager!
    private var updates: Updates!
    private var login: LoginLaunch!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        manager = WindowManager()
        updates = Updates()
        login = LoginLaunch()
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: "SnapSet")
            button.image?.isTemplate = true
            button.toolTip = "SnapSet — click to open, right-click for menu"
            button.target = self
            button.action = #selector(statusClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
        openWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openWindow()
        return true
    }

    @objc private func statusClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp { showMenu() }
        else { openWindow() }
    }

    @objc private func openWindow() {
        if window == nil {
            let controller = NSHostingController(rootView: LayoutView(manager: manager, updates: updates)
                .frame(minWidth: 1000, minHeight: 640))
            let settings = NSWindow(contentViewController: controller)
            settings.title = "SnapSet"
            settings.identifier = NSUserInterfaceItemIdentifier("layout")
            settings.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            settings.setContentSize(NSSize(width: 1180, height: 760))
            settings.minSize = NSSize(width: 1000, height: 640)
            settings.isReleasedWhenClosed = false
            settings.setFrameAutosaveName("SnapSetLayoutWindow")
            if !settings.setFrameUsingName("SnapSetLayoutWindow") { settings.center() }
            window = settings
        }
        window?.deminiaturize(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func showMenu() {
        guard let statusItem else { return }
        login.refresh()
        let menu = NSMenu()
        menu.autoenablesItems = false
        func action(_ title: String, _ selector: Selector, enabled: Bool = true, checked: Bool? = nil) {
            let item = menu.addItem(withTitle: title, action: selector, keyEquivalent: "")
            item.target = self
            item.isEnabled = enabled
            if let checked { item.state = checked ? .on : .off }
        }
        action("Apply layout", #selector(applyLayout), enabled: !manager.busy && manager.storageError == nil)
        action("Open SnapSet…", #selector(openWindow))
        menu.addItem(.separator())
        action("Launch at login", #selector(toggleLogin), checked: login.requested)
        if !login.message.isEmpty {
            let note = menu.addItem(withTitle: login.message, action: nil, keyEquivalent: "")
            note.isEnabled = false
            action("Open Login Items…", #selector(openLoginSettings))
        }
        action("Apply after display changes", #selector(toggleReconnect), checked: manager.configuration.onReconnect)
        menu.addItem(.separator())
        action("Check for Updates…", #selector(checkForUpdates), enabled: updates.canCheck)
        action("Quit SnapSet", #selector(quit))
        let note = menu.addItem(withTitle: "Default: Main display · Wide centered", action: nil, keyEquivalent: "")
        note.isEnabled = false
        // Attach only while tracking the right-click menu. Keeping it attached
        // would cause macOS to intercept subsequent left-clicks too.
        statusItem.menu = menu
        defer { statusItem.menu = nil }
        statusItem.button?.performClick(nil)
    }

    @objc private func applyLayout() { manager.apply() }
    @objc private func toggleLogin() { login.setEnabled(!login.requested) }
    @objc private func openLoginSettings() { login.openSettings() }
    @objc private func toggleReconnect() { manager.configuration.onReconnect.toggle() }
    @objc private func checkForUpdates() { updates.check() }
    @objc private func quit() { NSApp.terminate(nil) }
}
