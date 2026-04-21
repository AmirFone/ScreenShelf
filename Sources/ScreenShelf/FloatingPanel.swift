import AppKit
import SwiftUI

final class FloatingPanel: NSPanel {
    var isPresented = false
    weak var statusBarButton: NSStatusBarButton?
    var onKeyEvent: ((NSEvent) -> Bool)?
    private var keyMonitor: Any?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(contentRect: NSRect, statusBarButton: NSStatusBarButton? = nil) {
        self.statusBarButton = statusBarButton

        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        level = .statusBar
        collectionBehavior = [.auxiliary, .stationary, .moveToActiveSpace, .fullScreenAuxiliary]
        isFloatingPanel = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        titlebarSeparatorStyle = .none
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        backgroundColor = .clear
        isOpaque = false
        animationBehavior = .none
        isReleasedWhenClosed = false

        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
    }

    func setContent<V: View>(_ view: V) {
        let hosting = NSHostingView(rootView: view.ignoresSafeArea())
        hosting.sizingOptions = []
        contentView = hosting
        contentView?.wantsLayer = true
        contentView?.layer?.cornerRadius = 12
        contentView?.layer?.masksToBounds = true
    }

    func open(below button: NSStatusBarButton) {
        let rectInWindow = button.convert(button.bounds, to: nil)
        guard let screenRect = button.window?.convertToScreen(rectInWindow) else { return }

        let panelW = frame.width
        let panelH = frame.height
        var x = screenRect.midX - panelW / 2
        let y = screenRect.minY - panelH - 4

        if let screen = NSScreen.main {
            let maxX = screen.frame.maxX
            x = max(screen.frame.minX + 4, min(x, maxX - panelW - 4))
        }

        setFrameOrigin(NSPoint(x: x, y: y))
        installKeyMonitor()
        orderFrontRegardless()
        makeKey()
        isPresented = true
        statusBarButton?.isHighlighted = true
    }

    override func resignKey() {
        super.resignKey()
        close()
    }

    override func close() {
        removeKeyMonitor()
        super.close()
        isPresented = false
        statusBarButton?.isHighlighted = false
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.onKeyEvent?(event) == true {
                return nil
            }
            return event
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
}
