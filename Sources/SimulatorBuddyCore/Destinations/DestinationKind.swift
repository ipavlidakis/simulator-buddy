import Foundation

/// Broad destination family supported by simulator-buddy.
public enum DestinationKind: String, Codable, CaseIterable, Sendable {
    /// iOS simulator destination from CoreSimulator.
    case simulator

    /// Physical iOS/iPadOS device from CoreDevice.
    case device

    /// Local Mac run destination, including Catalyst and Designed for iPad variants.
    case macOS = "macos"

    /// Human-readable label used in tables and picker sections.
    public var displayName: String {
        switch self {
        case .simulator:
            return "Simulator"
        case .device:
            return "Device"
        case .macOS:
            return "Mac"
        }
    }
}
