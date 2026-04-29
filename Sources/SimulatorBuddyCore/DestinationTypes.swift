import Foundation

public enum DestinationKind: String, Codable, CaseIterable, Sendable {
    case simulator
    case device
    case macOS = "macos"

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

public enum DestinationQueryType: String, Codable, CaseIterable, Sendable {
    case simulator
    case device
    case macOS = "macos"
    case macOSCatalyst = "macos-catalyst"
    case macOSDesignedForIPad = "macos-designed-for-ipad"
    case all

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

    public func includes(_ kind: DestinationKind) -> Bool {
        kinds.contains(kind)
    }

    /// Subset of this query that only applies when sourcing Mac rows from Xcode.
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

/// How to filter `platform:macOS` rows parsed from `xcodebuild -showdestinations`.
public enum MacOSRecordsFilter: Sendable {
    case allVariants
    case catalyst
    case designedForIPad

    public func filteredRecords(from records: [DestinationRecord]) -> [DestinationRecord] {
        switch self {
        case .allVariants:
            return records
        case .catalyst:
            return records.filter {
                ($0.macOSVariant ?? "").localizedCaseInsensitiveContains("catalyst")
            }
        case .designedForIPad:
            return records.filter {
                ($0.macOSVariant ?? "").localizedCaseInsensitiveContains("ipad")
            }
        }
    }
}

public enum DestinationState: String, Codable, CaseIterable, Sendable {
    case booted
    case shutdown
    case connected
    case available
    case unavailable
    case disconnected
    case unknown

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

public struct DestinationRecord: Codable, Equatable, Identifiable, Sendable {
    public let kind: DestinationKind
    public let udid: String
    public let name: String
    public let runtime: String?
    public let state: DestinationState
    public let stateDescription: String
    public let lastBootedAt: Date?
    public let sourceIdentifier: String?
    /// When sourced from `xcodebuild -showdestinations` (e.g. `Mac Catalyst`).
    public let macOSVariant: String?
    /// Pass-through for `xcodebuild -destination` (for example `platform=macOS,variant=Mac Catalyst,id=...`).
    public let xcodeDestinationSpecifier: String?

    public init(
        kind: DestinationKind,
        udid: String,
        name: String,
        runtime: String?,
        state: DestinationState,
        stateDescription: String,
        lastBootedAt: Date? = nil,
        sourceIdentifier: String? = nil,
        macOSVariant: String? = nil,
        xcodeDestinationSpecifier: String? = nil
    ) {
        self.kind = kind
        self.udid = udid
        self.name = name
        self.runtime = runtime
        self.state = state
        self.stateDescription = stateDescription
        self.lastBootedAt = lastBootedAt
        self.sourceIdentifier = sourceIdentifier
        self.macOSVariant = macOSVariant
        self.xcodeDestinationSpecifier = xcodeDestinationSpecifier
    }

    public var id: String {
        selectionIdentifier
    }

    public var selectionIdentifier: String {
        xcodeDestinationSpecifier ?? udid
    }

    public func matches(searchText: String) -> Bool {
        let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard needle.isEmpty == false else {
            return true
        }

        let haystack = [
            name,
            runtime ?? "",
            stateDescription,
            udid,
            macOSVariant ?? "",
            xcodeDestinationSpecifier ?? "",
        ].joined(separator: " ").lowercased()

        return haystack.contains(needle.lowercased())
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case udid
        case name
        case runtime
        case state
        case stateDescription
        case lastBootedAt
        case sourceIdentifier
        case macOSVariant
        case xcodeDestinationSpecifier
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decode(DestinationKind.self, forKey: .kind)
        udid = try container.decode(String.self, forKey: .udid)
        name = try container.decode(String.self, forKey: .name)
        runtime = try container.decodeIfPresent(String.self, forKey: .runtime)
        state = try container.decode(DestinationState.self, forKey: .state)
        stateDescription = try container.decode(String.self, forKey: .stateDescription)
        lastBootedAt = try container.decodeIfPresent(Date.self, forKey: .lastBootedAt)
        sourceIdentifier = try container.decodeIfPresent(String.self, forKey: .sourceIdentifier)
        macOSVariant = try container.decodeIfPresent(String.self, forKey: .macOSVariant)
        xcodeDestinationSpecifier = try container.decodeIfPresent(
            String.self,
            forKey: .xcodeDestinationSpecifier
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encode(udid, forKey: .udid)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(runtime, forKey: .runtime)
        try container.encode(state, forKey: .state)
        try container.encode(stateDescription, forKey: .stateDescription)
        try container.encodeIfPresent(lastBootedAt, forKey: .lastBootedAt)
        try container.encodeIfPresent(sourceIdentifier, forKey: .sourceIdentifier)
        try container.encodeIfPresent(macOSVariant, forKey: .macOSVariant)
        try container.encodeIfPresent(xcodeDestinationSpecifier, forKey: .xcodeDestinationSpecifier)
    }
}

public struct HistoryEntry: Codable, Equatable, Sendable {
    public let kind: DestinationKind
    public let udid: String
    public let name: String
    public let runtime: String?
    public let selectedAt: Date

    public init(
        kind: DestinationKind,
        udid: String,
        name: String,
        runtime: String?,
        selectedAt: Date
    ) {
        self.kind = kind
        self.udid = udid
        self.name = name
        self.runtime = runtime
        self.selectedAt = selectedAt
    }
}

public struct ResolvedSelection: Codable, Equatable, Sendable {
    public let destination: DestinationRecord
    public let scope: SelectionScope?
    public let selectedAt: Date

    public init(destination: DestinationRecord, scope: SelectionScope?, selectedAt: Date) {
        self.destination = destination
        self.scope = scope
        self.selectedAt = selectedAt
    }
}

public enum SimulatorBuddyError: Error, LocalizedError, Sendable {
    case usage(String)
    case commandFailed(String)
    case noHistory(DestinationQueryType)
    case historyDestinationUnavailable(String)
    case noDestinations(DestinationQueryType)
    case guiUnavailable

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

extension DestinationRecord {
    var sortKey: (Int, String, String) {
        (
            state.sortPriority,
            runtime ?? "",
            name
        )
    }
}
