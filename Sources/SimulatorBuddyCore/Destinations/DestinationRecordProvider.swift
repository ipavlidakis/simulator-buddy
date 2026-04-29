import Foundation

/// Fetches destination records for a user-facing query type.
final class DestinationRecordProvider: @unchecked Sendable {
    /// Low-level fetcher backed by system tools or tests.
    private let fetcher: any DestinationFetching

    /// Creates a provider around the supplied destination fetcher.
    init(fetcher: any DestinationFetching) {
        self.fetcher = fetcher
    }

    /// Returns records for the query, applying Mac variant rules when needed.
    func fetchRecords(
        for type: DestinationQueryType,
        xcodeContext: XcodeSchemeContext?
    ) async throws -> [DestinationRecord] {
        switch type {
        case .simulator:
            return try await fetcher.fetchSimulators()
        case .device:
            return try await fetcher.fetchDevices()
        case .macOS:
            return try await fetchMacDestinationRecords(
                queryType: .macOS,
                xcodeContext: xcodeContext,
                filter: .allVariants
            )
        case .macOSCatalyst:
            return try await fetchMacDestinationRecords(
                queryType: .macOSCatalyst,
                xcodeContext: xcodeContext,
                filter: .catalyst
            )
        case .macOSDesignedForIPad:
            return try await fetchMacDestinationRecords(
                queryType: .macOSDesignedForIPad,
                xcodeContext: xcodeContext,
                filter: .designedForIPad
            )
        case .all:
            return try await fetchAllRecords(xcodeContext: xcodeContext)
        }
    }

    /// Loads Mac records from Xcode when context exists, otherwise from generic Mac tooling.
    private func fetchMacDestinationRecords(
        queryType: DestinationQueryType,
        xcodeContext: XcodeSchemeContext?,
        filter: MacOSRecordsFilter
    ) async throws -> [DestinationRecord] {
        if let xcodeContext {
            let raw = try await fetcher.fetchMacRunDestinationsFromXcode(context: xcodeContext)
            let out = filter.filteredRecords(from: raw)
            if filter != .allVariants, out.isEmpty {
                throw SimulatorBuddyError.noDestinations(queryType)
            }
            return out
        }

        if filter != .allVariants {
            throw SimulatorBuddyError.usage(
                """
                --type \(queryType.rawValue) requires --xcode-scheme and one of \
                --xcode-project or --xcode-workspace.
                """
            )
        }

        return try await fetcher.fetchMacs()
    }

    /// Fetches every supported family concurrently and returns sorted records.
    private func fetchAllRecords(xcodeContext: XcodeSchemeContext?) async throws -> [DestinationRecord] {
        async let simulators = fetcher.fetchSimulators()
        async let devices = fetcher.fetchDevices()
        async let macs: [DestinationRecord] = {
            if let xcodeContext {
                return try await fetcher.fetchMacRunDestinationsFromXcode(context: xcodeContext)
            }
            return try await fetcher.fetchMacs()
        }()

        return try await (simulators + devices + macs)
            .sorted { lhs, rhs in
                if lhs.kind != rhs.kind {
                    return lhs.kind.rawValue < rhs.kind.rawValue
                }
                return lhs.sortKey < rhs.sortKey
            }
    }
}
