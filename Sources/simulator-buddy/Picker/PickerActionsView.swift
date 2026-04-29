import SimulatorBuddyCore
import SwiftUI

/// Bottom action bar for cancelling or confirming picker selection.
struct PickerActionsView: View {
    /// View model receiving cancel and select actions.
    @ObservedObject var viewModel: DestinationPickerViewModel

    /// SwiftUI body containing the action buttons.
    var body: some View {
        HStack {
            Button("Cancel") {
                viewModel.cancel()
            }

            Spacer()

            Button("Select") {
                viewModel.chooseSelected()
            }
            .disabled(viewModel.selectedRecord(identifier: viewModel.selectedIdentifier) == nil)
            .keyboardShortcut(.defaultAction)
        }
    }
}
