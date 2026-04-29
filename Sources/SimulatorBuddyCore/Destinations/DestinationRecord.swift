import Foundation

/// Normalized destination row used by CLI output, picker UI, history, and xcodebuild injection.
public struct DestinationRecord: Codable, Equatable, Identifiable, Sendable {
    /// Broad family for this destination.
    public let kind: DestinationKind

    /// Stable destination identifier, usually a UDID or Mac hardware identifier.
    public let udid: String

    /// Display name supplied by the source tool.
    public let name: String

    /// Runtime or OS label, when known.
    public let runtime: String?

    /// Normalized current availability state.
    public let state: DestinationState

    /// Source-specific state text kept for display and diagnostics.
    public let stateDescription: String

    /// Simulator boot timestamp when provided by simctl.
    public let lastBootedAt: Date?

    /// Identifier for the source bucket that produced the record.
    public let sourceIdentifier: String?

    /// Xcode Mac variant, such as Catalyst or Designed for iPad.
    public let macOSVariant: String?

    /// Full `xcodebuild -destination` specifier for this row.
    public let xcodeDestinationSpecifier: String?

    /// Creates a normalized destination record.
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

    /// Identifier used by SwiftUI lists.
    public var id: String {
        selectionIdentifier
    }

    /// Identifier that should be passed to downstream selection consumers.
    public var selectionIdentifier: String {
        xcodeDestinationSpecifier ?? udid
    }

    /// Sort tuple used to keep preferred destinations near the top.
    var sortKey: (Int, String, String) {
        (state.sortPriority, runtime ?? "", name)
    }

    /// Returns whether the record matches a picker search string.
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
}
