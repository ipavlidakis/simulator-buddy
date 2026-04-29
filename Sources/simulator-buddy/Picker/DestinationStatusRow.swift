import SwiftUI

/// Non-selectable status row shown inside a picker section.
struct DestinationStatusRow: View {
    /// Status text to display.
    let text: String

    /// SwiftUI body displaying compact status text.
    var body: some View {
        Text(text)
            .font(.caption)
    }
}
