import AppKit
import SwiftUI

// A local monitor keeps the unmodified shortcut inside the settings window.
// Text editors retain '/' for document paths, title patterns, and search text.
struct SearchShortcut: NSViewRepresentable {
    var focusSearch: () -> Void

    func makeNSView(context: Context) -> ShortcutView {
        let view = ShortcutView()
        view.focusSearch = focusSearch
        return view
    }
    func updateNSView(_ view: ShortcutView, context: Context) { view.focusSearch = focusSearch }

    final class ShortcutView: NSView {
        var focusSearch: (() -> Void)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, let window = self.window,
                      window.isKeyWindow, event.window === window,
                      event.characters == "/",
                      event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return event }
                if let editor = window.firstResponder as? NSTextView, editor.isEditable { return event }
                if let field = window.firstResponder as? NSTextField, field.isEditable { return event }
                self.focusSearch?()
                return nil
            }
        }
        deinit { if let monitor { NSEvent.removeMonitor(monitor) } }
    }
}
