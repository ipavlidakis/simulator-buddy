import AppKit
import CoreGraphics
import SimulatorBuddyCore
import SwiftUI

final class NativePickerPresenter: PickerPresenting, @unchecked Sendable {
    private let loader: DestinationSelectionLoader

    init(
        fetcher: any DestinationFetching,
        cacheStore: any DestinationCacheStoring,
        historyStore: any HistoryProviding
    ) {
        loader = DestinationSelectionLoader(
            fetcher: fetcher,
            cacheStore: cacheStore,
            historyStore: historyStore
        )
    }

    @MainActor
    func present(
        queryType: DestinationQueryType,
        scope: SelectionScope?
    ) async throws -> DestinationRecord {
        guard Self.hasGUISession else {
            throw SimulatorBuddyError.guiUnavailable
        }

        let loadedSelection = try await loader.load(queryType: queryType, scope: scope)
        let viewModel = DestinationPickerViewModel(loadedSelection: loadedSelection)

        let application = NSApplication.shared
        let windowController = PickerWindowController(viewModel: viewModel)
        var result: Result<DestinationRecord, DestinationPickerFailure>?

        viewModel.onResolve = { outcome in
            result = outcome
            windowController.close()
            application.stop(nil)
        }

        application.setActivationPolicy(.regular)
        application.activate(ignoringOtherApps: true)

        windowController.showWindow(nil)
        application.run()

        switch result {
        case let .success(record):
            return record
        case let .failure(error):
            throw error
        case .none:
            throw DestinationPickerFailure.cancelled
        }
    }

    private static var hasGUISession: Bool {
        guard let dictionary = CGSessionCopyCurrentDictionary() as? [AnyHashable: Any] else {
            return false
        }

        return GUISessionInspector.hasGUISession(sessionInfo: dictionary)
    }
}

@MainActor
private final class PickerWindowController: NSWindowController, NSWindowDelegate {
    private let viewModel: DestinationPickerViewModel

    init(viewModel: DestinationPickerViewModel) {
        self.viewModel = viewModel

        let hostingController = NSHostingController(rootView: PickerRootView(viewModel: viewModel))
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Simulator Buddy"
        window.setContentSize(NSSize(width: 720, height: 520))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.center()
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func windowWillClose(_ notification: Notification) {
        viewModel.cancel()
    }
}

private struct PickerRootView: View {
    @ObservedObject var viewModel: DestinationPickerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Select Destination")
                    .font(.title2.weight(.semibold))
                Spacer()
            }

            TextField("Search by name, runtime, state, or UDID", text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }

            List(selection: $viewModel.selectedUDID) {
                if viewModel.queryType.includes(.simulator) {
                    Section("Simulators") {
                        if let simulatorErrorMessage = viewModel.simulatorErrorMessage,
                           viewModel.displayedSimulators.isEmpty {
                            statusRow(text: simulatorErrorMessage)
                        }

                        ForEach(viewModel.displayedSimulators) { record in
                            destinationRow(for: record)
                                .tag(record.udid)
                        }
                    }
                }

                if viewModel.queryType.includes(.device) {
                    Section("Devices") {
                        if let deviceErrorMessage = viewModel.deviceErrorMessage,
                           viewModel.displayedDevices.isEmpty {
                            statusRow(text: deviceErrorMessage)
                        }

                        ForEach(viewModel.displayedDevices) { record in
                            destinationRow(for: record)
                                .tag(record.udid)
                        }
                    }
                }

                if viewModel.queryType.includes(.macOS) {
                    Section("Macs") {
                        if let macErrorMessage = viewModel.macErrorMessage,
                           viewModel.displayedMacs.isEmpty {
                            statusRow(text: macErrorMessage)
                        }

                        ForEach(viewModel.displayedMacs) { record in
                            destinationRow(for: record)
                                .tag(record.udid)
                        }
                    }
                }
            }
            .onSubmit {
                viewModel.chooseSelected()
            }

            HStack {
                Button("Cancel") {
                    viewModel.cancel()
                }

                Spacer()

                Button("Select") {
                    viewModel.chooseSelected()
                }
                .disabled(viewModel.selectedRecord(udid: viewModel.selectedUDID) == nil)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
    }

    @ViewBuilder
    private func statusRow(text: String) -> some View {
        Text(text)
            .font(.caption)
    }

    @ViewBuilder
    private func destinationRow(for record: DestinationRecord) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(record.name)

            Text([
                record.runtime ?? "Unknown OS",
                record.stateDescription,
                record.udid,
            ].joined(separator: " | "))
                .font(.caption)

            if viewModel.isPinned(record) {
                Text("Last used")
                    .font(.caption2)
            }
        }
    }
}
