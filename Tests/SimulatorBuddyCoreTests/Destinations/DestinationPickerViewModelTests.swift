import Foundation
import Testing
@testable import SimulatorBuddyCore

/// Main-actor tests for picker state, selection, and Mac specifier handling.
@MainActor
struct DestinationPickerViewModelTests {
    /// Verifies previous simulator history is preferred as initial selection.
    @Test
    func init_prefersLastUsedSimulatorSelection() {
        let simulator = DestinationRecord(
            kind: .simulator,
            udid: "SIM-1",
            name: "iPhone Air",
            runtime: "iOS 26.5",
            state: .booted,
            stateDescription: "Booted"
        )
        let device = DestinationRecord(
            kind: .device,
            udid: "DEVICE-1",
            name: "iPhone Blue",
            runtime: "iOS 26.4",
            state: .connected,
            stateDescription: "Connected"
        )

        let viewModel = DestinationPickerViewModel(
            loadedSelection: LoadedDestinationSelection(
                queryType: .all,
                scope: SelectionScope(explicit: "workspace"),
                simulatorRecords: [simulator],
                deviceRecords: [device],
                macRecords: [],
                simulatorErrorMessage: nil,
                deviceErrorMessage: nil,
                macErrorMessage: nil,
                lastSimulatorEntry: HistoryEntry(
                    kind: .simulator,
                    udid: "SIM-1",
                    name: simulator.name,
                    runtime: simulator.runtime,
                    selectedAt: Date(timeIntervalSince1970: 10)
                ),
                lastDeviceEntry: nil,
                lastMacEntry: nil
            )
        )

        #expect(viewModel.selectedIdentifier == "SIM-1")
        #expect(viewModel.isPinned(simulator))
    }

    /// Verifies choosing the selected row resolves the picker immediately.
    @Test
    func chooseSelected_resolvesImmediately() {
        let simulator = DestinationRecord(
            kind: .simulator,
            udid: "SIM-1",
            name: "iPhone Air",
            runtime: "iOS 26.5",
            state: .booted,
            stateDescription: "Booted"
        )
        let viewModel = DestinationPickerViewModel(
            loadedSelection: LoadedDestinationSelection(
                queryType: .simulator,
                scope: SelectionScope(explicit: "workspace"),
                simulatorRecords: [simulator],
                deviceRecords: [],
                macRecords: [],
                simulatorErrorMessage: nil,
                deviceErrorMessage: nil,
                macErrorMessage: nil,
                lastSimulatorEntry: nil,
                lastDeviceEntry: nil,
                lastMacEntry: nil
            )
        )

        let output = OutputRecorder()
        viewModel.onResolve = { result in
            switch result {
            case let .success(record):
                output.write(record.udid)
            case let .failure(error):
                output.write(error.localizedDescription)
            }
        }

        viewModel.chooseSelected()

        #expect(output.snapshot() == ["SIM-1"])
    }

    /// Verifies duplicate Mac UDIDs stay distinguishable through xcodebuild specifiers.
    @Test
    func selectedRecord_usesXcodeDestinationSpecifierForDuplicateMacIds() {
        let ipadRecord = DestinationRecord(
            kind: .macOS,
            udid: "MAC-UDID-1",
            name: "My Mac - Designed for [iPad,iPhone]",
            runtime: "Designed for [iPad,iPhone]",
            state: .available,
            stateDescription: "Available",
            macOSVariant: "Designed for [iPad,iPhone]",
            xcodeDestinationSpecifier: "platform=macOS,variant=Designed for iPad,id=MAC-UDID-1"
        )
        let catalystRecord = DestinationRecord(
            kind: .macOS,
            udid: "MAC-UDID-1",
            name: "My Mac - Mac Catalyst",
            runtime: "Mac Catalyst",
            state: .available,
            stateDescription: "Available",
            macOSVariant: "Mac Catalyst",
            xcodeDestinationSpecifier: "platform=macOS,variant=Mac Catalyst,id=MAC-UDID-1"
        )
        let viewModel = DestinationPickerViewModel(
            loadedSelection: LoadedDestinationSelection(
                queryType: .macOS,
                scope: nil,
                simulatorRecords: [],
                deviceRecords: [],
                macRecords: [ipadRecord, catalystRecord],
                simulatorErrorMessage: nil,
                deviceErrorMessage: nil,
                macErrorMessage: nil,
                lastSimulatorEntry: nil,
                lastDeviceEntry: nil,
                lastMacEntry: nil
            )
        )

        viewModel.selectedIdentifier = catalystRecord.selectionIdentifier

        #expect(viewModel.selectedRecord(identifier: viewModel.selectedIdentifier) == catalystRecord)
    }
}
