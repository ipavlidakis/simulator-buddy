import Foundation

/// User-facing destination filter accepted by CLI commands.
public enum DestinationQueryType: String, Codable, CaseIterable, Sendable {
    /// Query only iOS simulators.
    case simulator

    /// Query only physical devices.
    case device

    /// Query all Mac run variants.
    case macOS = "macos"

    /// Query Mac Catalyst variants for an Xcode scheme.
    case macOSCatalyst = "macos-catalyst"

    /// Query Designed for iPad/iPhone Mac variants for an Xcode scheme.
    case macOSDesignedForIPad = "macos-designed-for-ipad"

    /// Query all supported destination families.
    case all

    /// Destination families that must be loaded for this query.
    public var kinds: [DestinationKind] {
        switch self {
        case .simulator:
            return [.simulator]
        case .device:
            return [.device]
        case .macOS, .macOSCatalyst, .macOSDesignedForIPad:
            return [.macOS]
        case .all:
            return DestinationKind.allCases
        }
    }

    /// Returns whether records of the given family belong to this query.
    public func includes(_ kind: DestinationKind) -> Bool {
        kinds.contains(kind)
    }

    /// Mac variant filter applied after Mac destinations are loaded.
    public var macOSRecordsFilter: MacOSRecordsFilter {
        switch self {
        case .macOSCatalyst:
            return .catalyst
        case .macOSDesignedForIPad:
            return .designedForIPad
        case .macOS, .all, .simulator, .device:
            return .allVariants
        }
    }
}
