import Foundation
import Testing
@testable import SimulatorBuddyCore

@MainActor
struct DestinationPickerViewModelTests {
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
                scope: SelectionScope.explicit("workspace"),
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

        #expect(viewModel.selectedUDID == "SIM-1")
        #expect(viewModel.isPinned(simulator))
    }

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
                scope: SelectionScope.explicit("workspace"),
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
}
