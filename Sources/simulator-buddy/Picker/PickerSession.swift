import AppKit
import SimulatorBuddyCore

@MainActor
/// Owns the local AppKit event loop used by the picker window.
final class PickerSession {
    /// View model bridged to the SwiftUI picker.
    private let viewModel: DestinationPickerViewModel

    /// Creates a picker session for the given view model.
    init(viewModel: DestinationPickerViewModel) {
        self.viewModel = viewModel
    }

    /// Presents the picker and suspends until selection or cancellation.
    func present() async throws -> DestinationRecord {
        let application = NSApplication.shared
        let windowController = PickerWindowController(viewModel: viewModel)
        var result: Result<DestinationRecord, DestinationPickerFailure>?

        viewModel.onResolve = { outcome in
            result = outcome
            windowController.closeAfterResolution()
        }

        show(windowController: windowController, application: application)
        runEventLoop(application: application, until: { result != nil })
        windowController.closeAfterResolution()

        switch result {
        case let .success(record):
            return record
        case let .failure(error):
            throw error
        case .none:
            throw DestinationPickerFailure.cancelled
        }
    }

    /// Shows the picker window in the active Space and brings it to the front.
    private func show(windowController: PickerWindowController, application: NSApplication) {
        application.finishLaunching()
        application.setActivationPolicy(.regular)
        windowController.showWindow(nil)
        windowController.window?.makeKeyAndOrderFront(nil)
        windowController.window?.orderFrontRegardless()
        application.activate(ignoringOtherApps: true)
        NSRunningApplication.current.activate(options: [.activateAllWindows])
    }

    /// Pumps AppKit events while the picker is visible.
    private func runEventLoop(application: NSApplication, until isFinished: () -> Bool) {
        while isFinished() == false {
            guard let event = application.nextEvent(
                matching: .any,
                until: .distantFuture,
                inMode: .default,
                dequeue: true
            ) else {
                continue
            }

            application.sendEvent(event)
        }
    }
}
