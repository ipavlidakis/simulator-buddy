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
    case all

    public var kinds: [DestinationKind] {
        switch self {
        case .simulator:
            return [.simulator]
        case .device:
            return [.device]
        case .macOS:
            return [.macOS]
        case .all:
            return DestinationKind.allCases
        }
    }

    public func includes(_ kind: DestinationKind) -> Bool {
        kinds.contains(kind)
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

    public init(
        kind: DestinationKind,
        udid: String,
        name: String,
        runtime: String?,
        state: DestinationState,
        stateDescription: String,
        lastBootedAt: Date? = nil,
        sourceIdentifier: String? = nil
    ) {
        self.kind = kind
        self.udid = udid
        self.name = name
        self.runtime = runtime
        self.state = state
        self.stateDescription = stateDescription
        self.lastBootedAt = lastBootedAt
        self.sourceIdentifier = sourceIdentifier
    }

    public var id: String {
        udid
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
        ].joined(separator: " ").lowercased()

        return haystack.contains(needle.lowercased())
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
