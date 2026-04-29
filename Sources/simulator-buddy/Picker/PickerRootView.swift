import SimulatorBuddyCore
import SwiftUI

/// Root view for the native destination picker window.
struct PickerRootView: View {
    /// View model shared by picker controls.
    @ObservedObject var viewModel: DestinationPickerViewModel

    /// SwiftUI body containing title, search field, list, and actions.
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select Destination")
                .font(.title2.weight(.semibold))

            TextField("Search by name, runtime, state, or UDID", text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }

            DestinationListView(viewModel: viewModel)
            PickerActionsView(viewModel: viewModel)
        }
        .padding(20)
    }
}
