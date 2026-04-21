import AppKit
import SwiftUI
import KeyboardShortcuts
import ServiceManagement

extension KeyboardShortcuts.Name {
    static let togglePanel = Self("togglePanel", default: .init(.x, modifiers: [.command, .shift]))
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: FloatingPanel?
    private var store: ScreenshotStore!

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.prohibited)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        do {
            let database = try AppDatabase()
            store = ScreenshotStore(database: database)
        } catch {
            fatalError("Failed to initialize database: \(error)")
        }

        setupStatusItem()
        setupKeyboardShortcut()
        enableLaunchAtLogin()

        Task { @MainActor in
            await store.indexExisting()
            await store.loadInitialPage()
            store.startWatching()
        }
    }

    private func enableLaunchAtLogin() {
        try? SMAppService.mainApp.register()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "photo.on.rectangle",
                accessibilityDescription: "ScreenShelf"
            )
            button.image?.isTemplate = true
            button.action = #selector(statusItemClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Quit ScreenShelf", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            togglePanel()
        }
    }

    private func setupKeyboardShortcut() {
        KeyboardShortcuts.onKeyDown(for: .togglePanel) { [weak self] in
            self?.togglePanel()
        }
    }

    private func togglePanel() {
        if let panel, panel.isPresented {
            panel.close()
            return
        }
        showPanel()
    }

    private func showPanel() {
        guard let button = statusItem.button else { return }

        if panel == nil {
            let p = FloatingPanel(
                contentRect: NSRect(x: 0, y: 0, width: 360, height: 440),
                statusBarButton: button
            )
            p.setContent(ContentView(store: store))
            p.onKeyEvent = { [weak self] event in
                self?.handleKeyEvent(event) ?? false
            }
            panel = p
        }

        MainActor.assumeIsolated { store.onPanelOpen() }
        panel?.open(below: button)
    }

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let shift = event.modifierFlags.contains(.shift)

        switch event.keyCode {
        case 125: // Down arrow
            MainActor.assumeIsolated { store.moveCursor(down: true, extendSelection: shift) }
            return true
        case 126: // Up arrow
            MainActor.assumeIsolated { store.moveCursor(down: false, extendSelection: shift) }
            return true
        case 36: // Return/Enter
            MainActor.assumeIsolated {
                if store.copySelected() { panel?.close() }
            }
            return true
        case 53: // Escape
            panel?.close()
            return true
        case 35: // P
            MainActor.assumeIsolated {
                store.copyMode = store.copyMode == .image ? .path : .image
            }
            return true
        default:
            return false
        }
    }
}
