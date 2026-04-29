import SimulatorBuddyCore
import SwiftUI

/// Picker list section for one destination family.
struct DestinationSectionView: View {
    /// Section title shown in the list.
    let title: String

    /// Records displayed in the section.
    let records: [DestinationRecord]

    /// Optional load error shown when records are unavailable.
    let errorMessage: String?

    /// View model used for pinning and selection tags.
    @ObservedObject var viewModel: DestinationPickerViewModel

    /// SwiftUI body containing status row and destination rows.
    var body: some View {
        Section(title) {
            if let errorMessage, records.isEmpty {
                DestinationStatusRow(text: errorMessage)
            }

            ForEach(records) { record in
                DestinationRowView(record: record, isPinned: viewModel.isPinned(record))
                    .tag(record.selectionIdentifier)
            }
        }
    }
}
