import SimulatorBuddyCore
import SwiftUI

/// Sectioned list of picker destinations for the visible query type.
struct DestinationListView: View {
    /// View model that owns records, filtering, and selection state.
    @ObservedObject var viewModel: DestinationPickerViewModel

    /// SwiftUI body containing destination sections.
    var body: some View {
        List(selection: $viewModel.selectedIdentifier) {
            if viewModel.queryType.includes(.simulator) {
                DestinationSectionView(
                    title: "Simulators",
                    records: viewModel.displayedSimulators,
                    errorMessage: viewModel.simulatorErrorMessage,
                    viewModel: viewModel
                )
            }

            if viewModel.queryType.includes(.device) {
                DestinationSectionView(
                    title: "Devices",
                    records: viewModel.displayedDevices,
                    errorMessage: viewModel.deviceErrorMessage,
                    viewModel: viewModel
                )
            }

            if viewModel.queryType.includes(.macOS) {
                DestinationSectionView(
                    title: "Macs",
                    records: viewModel.displayedMacs,
                    errorMessage: viewModel.macErrorMessage,
                    viewModel: viewModel
                )
            }
        }
        .onSubmit {
            viewModel.chooseSelected()
        }
    }
}
