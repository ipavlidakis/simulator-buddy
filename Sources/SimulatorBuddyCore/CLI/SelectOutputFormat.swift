import Foundation

/// Output format supported by destination-printing commands.
enum SelectOutputFormat: String {
    /// Print only the selected destination identifier.
    case udid

    /// Print JSON for machines and automation.
    case json

    /// Print a human-readable table.
    case table
}
