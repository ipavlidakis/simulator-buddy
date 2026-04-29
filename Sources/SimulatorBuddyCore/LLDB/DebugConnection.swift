import Foundation

/// JSON payload emitted by the compatibility `debug` command.
struct DebugConnection: Encodable {
    /// Destination selected for debugger attachment.
    let destination: DestinationRecord

    /// Selection scope used to update last-used history.
    let scope: SelectionScope?

    /// Timestamp recorded when the destination was selected.
    let selectedAt: Date

    /// Absolute path to the generated LLDB command file.
    let lldbCommandFile: String
}
