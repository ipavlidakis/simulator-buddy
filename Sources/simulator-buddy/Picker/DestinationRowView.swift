import SimulatorBuddyCore
import SwiftUI

/// Single selectable row in the destination picker.
struct DestinationRowView: View {
    /// Destination represented by this row.
    let record: DestinationRecord

    /// Indicates whether this row is the last-used destination.
    let isPinned: Bool

    /// SwiftUI body displaying primary name, metadata, and pin label.
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(record.name)

            Text(subtitle)
                .font(.caption)

            if isPinned {
                Text("Last used")
                    .font(.caption2)
            }
        }
    }

    /// Compact metadata line shown below the destination name.
    private var subtitle: String {
        [
            record.runtime ?? "Unknown OS",
            record.stateDescription,
            record.udid,
        ].joined(separator: " | ")
    }
}
