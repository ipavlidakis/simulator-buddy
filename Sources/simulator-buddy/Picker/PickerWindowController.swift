import AppKit
import SimulatorBuddyCore
import SwiftUI

@MainActor
/// Window controller hosting the SwiftUI picker root.
final class PickerWindowController: NSWindowController, NSWindowDelegate {
    /// View model cancelled when the window closes.
    private let viewModel: DestinationPickerViewModel

    /// Whether window closure should resolve the picker as cancelled.
    private var shouldCancelOnClose = true

    /// Creates a configured picker window.
    init(viewModel: DestinationPickerViewModel) {
        self.viewModel = viewModel

        let hostingController = NSHostingController(rootView: PickerRootView(viewModel: viewModel))
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Simulator Buddy"
        window.setContentSize(NSSize(width: 720, height: 520))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.collectionBehavior = [.moveToActiveSpace]
        window.center()
        super.init(window: window)
        window.delegate = self
    }

    /// Storyboard initialization is unsupported for programmatic picker windows.
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    /// Hides the window after the picker has already resolved.
    func closeAfterResolution() {
        shouldCancelOnClose = false
        window?.orderOut(nil)
    }

    /// Treats window close as picker cancellation.
    func windowWillClose(_ notification: Notification) {
        guard shouldCancelOnClose else {
            return
        }

        viewModel.cancel()
    }
}
