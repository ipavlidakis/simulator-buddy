import Foundation

/// User-facing errors raised by command parsing and destination resolution.
public enum SimulatorBuddyError: Error, LocalizedError, Sendable {
    /// The command line is invalid and should show the supplied usage message.
    case usage(String)

    /// A required subprocess failed and produced the supplied diagnostic.
    case commandFailed(String)

    /// No last-used destination exists for the requested query type.
    case noHistory(DestinationQueryType)

    /// A stored destination identifier no longer appears in live destination data.
    case historyDestinationUnavailable(String)

    /// No live destination exists for the requested query type.
    case noDestinations(DestinationQueryType)

    /// The process is not attached to a GUI-capable macOS session.
    case guiUnavailable

    /// Localized description suitable for stderr output.
    public var errorDescription: String? {
        switch self {
        case let .usage(message):
            return message
        case let .commandFailed(message):
            return message
        case let .noHistory(type):
            return "No stored \(type.rawValue) destination history was found."
        case let .historyDestinationUnavailable(udid):
            return "The last-used destination \(udid) is not currently available."
        case let .noDestinations(type):
            return "No \(type.rawValue) destinations are currently available."
        case .guiUnavailable:
            return "A macOS GUI session is required to use `select`."
        }
    }
}
