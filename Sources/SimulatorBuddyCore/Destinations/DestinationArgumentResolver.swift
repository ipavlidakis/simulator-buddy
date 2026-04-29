import Foundation

/// Resolves attach destination arguments into normalized destination records.
final class DestinationArgumentResolver: @unchecked Sendable {
    /// Provider used to match supplied UDIDs against live records.
    private let recordProvider: DestinationRecordProvider

    /// Creates a resolver backed by a destination record provider.
    init(recordProvider: DestinationRecordProvider) {
        self.recordProvider = recordProvider
    }

    /// Resolves a UDID or xcodebuild destination specifier for attach.
    func resolve(_ value: String, type: DestinationQueryType) async throws -> DestinationRecord {
        if let parsed = record(fromSpecifier: value) {
            return parsed
        }

        if let records = try? await recordProvider.fetchRecords(for: .all, xcodeContext: nil),
           let record = records.first(where: { $0.udid == value || $0.selectionIdentifier == value }) {
            return record
        }

        return DestinationRecord(
            kind: fallbackKind(for: type),
            udid: value,
            name: value,
            runtime: nil,
            state: .available,
            stateDescription: "Available"
        )
    }

    /// Parses a destination record directly from an xcodebuild destination specifier.
    private func record(fromSpecifier value: String) -> DestinationRecord? {
        let normalized = value.replacingOccurrences(of: ":", with: "=")
        guard normalized.contains("platform="),
              let id = field(named: "id", in: normalized)
        else {
            return nil
        }

        let kind: DestinationKind
        if normalized.localizedCaseInsensitiveContains("platform=iOS Simulator") {
            kind = .simulator
        } else if normalized.localizedCaseInsensitiveContains("platform=iOS") {
            kind = .device
        } else if normalized.localizedCaseInsensitiveContains("platform=macOS") {
            kind = .macOS
        } else {
            return nil
        }

        return DestinationRecord(
            kind: kind,
            udid: id,
            name: id,
            runtime: nil,
            state: .available,
            stateDescription: "Available",
            xcodeDestinationSpecifier: value
        )
    }

    /// Reads one comma-delimited field from an xcodebuild destination specifier.
    private func field(named name: String, in value: String) -> String? {
        guard let range = value.range(of: "\(name)=") else {
            return nil
        }

        let start = range.upperBound
        let end = value[start...].firstIndex(of: ",") ?? value.endIndex
        let field = value[start..<end].trimmingCharacters(in: .whitespacesAndNewlines)
        return field.isEmpty ? nil : field
    }

    /// Chooses a destination family when no live record can be found.
    private func fallbackKind(for type: DestinationQueryType) -> DestinationKind {
        switch type {
        case .simulator:
            return .simulator
        case .device:
            return .device
        case .macOS, .macOSCatalyst, .macOSDesignedForIPad:
            return .macOS
        case .all:
            return .device
        }
    }
}
