import AppKit

/// Prevents picker window closure from terminating the command-line process.
final class PickerApplicationDelegate: NSObject, NSApplicationDelegate {
    /// Blocks AppKit termination requests while the CLI owns process lifetime.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        .terminateCancel
    }

    /// Keeps the CLI alive after the picker window closes.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
