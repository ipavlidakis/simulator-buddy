import Foundation

/// Failure conditions produced by the native destination picker.
public enum DestinationPickerFailure: Error, LocalizedError, Sendable {
    /// User cancelled the picker.
    case cancelled

    /// Picker has no records for the requested query.
    case noDestinations(DestinationQueryType)

    /// Human-readable failure message for stderr.
    public var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Selection cancelled."
        case let .noDestinations(type):
            return "No \(type.rawValue) destinations are currently available."
        }
    }
}
