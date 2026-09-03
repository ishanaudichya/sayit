import AppKit
import Carbon.HIToolbox

/// Watches the Fn/globe key globally. Requires Accessibility permission —
/// without it the global monitor simply never fires.
@MainActor
final class HotkeyMonitor {
    var onFnDown: (() -> Void)?
    var onFnUp: (() -> Void)?

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var fnIsDown = false

    func start() {
        stop()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
        fnIsDown = false
    }

    private func handle(_ event: NSEvent) {
        // Only react to the Fn key itself, not other modifiers.
        guard event.keyCode == UInt16(kVK_Function) else { return }
        let down = event.modifierFlags.contains(.function)
        guard down != fnIsDown else { return }
        fnIsDown = down
        if down {
            onFnDown?()
        } else {
            onFnUp?()
        }
    }
}
