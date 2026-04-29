import Foundation

/// Normalized availability state across simulators, devices, and Mac destinations.
public enum DestinationState: String, Codable, CaseIterable, Sendable {
    /// Simulator is booted.
    case booted

    /// Simulator is shutdown.
    case shutdown

    /// Physical device is connected and usable.
    case connected

    /// Mac destination is available.
    case available

    /// Destination exists but cannot currently run.
    case unavailable

    /// Physical device is known but disconnected.
    case disconnected

    /// Source-specific state could not be normalized.
    case unknown

    /// Stable ordering priority for picker and table display.
    var sortPriority: Int {
        switch self {
        case .booted, .connected:
            return 0
        case .available:
            return 1
        case .shutdown:
            return 2
        case .disconnected:
            return 3
        case .unavailable:
            return 4
        case .unknown:
            return 5
        }
    }

    /// Human-readable state label.
    public var displayName: String {
        switch self {
        case .booted:
            return "Booted"
        case .shutdown:
            return "Shutdown"
        case .connected:
            return "Connected"
        case .available:
            return "Available"
        case .unavailable:
            return "Unavailable"
        case .disconnected:
            return "Disconnected"
        case .unknown:
            return "Unknown"
        }
    }
}
