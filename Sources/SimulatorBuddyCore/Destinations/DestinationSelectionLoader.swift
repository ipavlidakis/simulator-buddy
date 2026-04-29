import Foundation

/// Loads all picker inputs: live records, cache updates, and last-used history.
public final class DestinationSelectionLoader: @unchecked Sendable {
    /// Fetcher used for live destinations.
    private let fetcher: any DestinationFetching

    /// Cache store updated after successful family fetches.
    private let cacheStore: any DestinationCacheStoring

    /// History store used to preselect prior destinations.
    private let historyStore: any HistoryProviding

    /// Clock used for cache timestamps.
    private let now: @Sendable () -> Date

    /// Creates a picker loader with injectable fetch, cache, and history dependencies.
    public init(
        fetcher: any DestinationFetching,
        cacheStore: any DestinationCacheStoring,
        historyStore: any HistoryProviding,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.fetcher = fetcher
        self.cacheStore = cacheStore
        self.historyStore = historyStore
        self.now = now
    }

    /// Loads records and history for the picker, preserving non-fatal family errors.
    public func load(
        queryType: DestinationQueryType,
        scope: SelectionScope?,
        xcodeContext: XcodeSchemeContext?
    ) async throws -> LoadedDestinationSelection {
        async let simulatorHistory: HistoryEntry? = {
            guard queryType.includes(.simulator) else {
                return nil
            }
            return try await historyStore.resolveLast(type: .simulator, scope: scope)
        }()
        async let deviceHistory: HistoryEntry? = {
            guard queryType.includes(.device) else {
                return nil
            }
            return try await historyStore.resolveLast(type: .device, scope: scope)
        }()
        async let macHistory: HistoryEntry? = {
            guard queryType.includes(.macOS) else {
                return nil
            }
            return try await historyStore.resolveLast(
                type: macHistoryQueryType(for: queryType),
                scope: scope
            )
        }()

        var simulatorRecords: [DestinationRecord] = []
        var deviceRecords: [DestinationRecord] = []
        var macRecords: [DestinationRecord] = []
        var simulatorErrorMessage: String?
        var deviceErrorMessage: String?
        var macErrorMessage: String?

        if queryType.includes(.simulator) {
            do {
                simulatorRecords = try await fetcher.fetchSimulators()
                _ = try? await cacheStore.update(
                    kind: .simulator,
                    records: simulatorRecords,
                    fetchedAt: now()
                )
            } catch {
                simulatorErrorMessage = error.localizedDescription
                if queryType == .simulator {
                    throw error
                }
            }
        }

        if queryType.includes(.device) {
            do {
                deviceRecords = try await fetcher.fetchDevices()
                _ = try? await cacheStore.update(
                    kind: .device,
                    records: deviceRecords,
                    fetchedAt: now()
                )
            } catch {
                deviceErrorMessage = error.localizedDescription
                if queryType == .device {
                    throw error
                }
            }
        }

        if queryType.includes(.macOS) {
            do {
                let variantFilter = queryType.macOSRecordsFilter
                if let xcodeContext {
                    let fromXcode = try await fetcher.fetchMacRunDestinationsFromXcode(
                        context: xcodeContext
                    )
                    macRecords = variantFilter.filteredRecords(from: fromXcode)
                    if variantFilter != .allVariants, macRecords.isEmpty {
                        throw SimulatorBuddyError.noDestinations(queryType)
                    }
                } else {
                    if variantFilter != .allVariants {
                        throw SimulatorBuddyError.usage(
                            """
                            --type \(queryType.rawValue) requires --xcode-scheme and one of \
                            --xcode-project or --xcode-workspace.
                            """
                        )
                    }
                    macRecords = try await fetcher.fetchMacs()
                }

                _ = try? await cacheStore.update(
                    kind: .macOS,
                    records: macRecords,
                    fetchedAt: now()
                )
            } catch {
                macErrorMessage = error.localizedDescription
                if isMacOnlyQuery(queryType) {
                    throw error
                }
            }
        }

        if queryType == .all, simulatorRecords.isEmpty, deviceRecords.isEmpty, macRecords.isEmpty {
            throw SimulatorBuddyError.noDestinations(.all)
        }

        return LoadedDestinationSelection(
            queryType: queryType,
            scope: scope,
            simulatorRecords: simulatorRecords,
            deviceRecords: deviceRecords,
            macRecords: macRecords,
            simulatorErrorMessage: simulatorErrorMessage,
            deviceErrorMessage: deviceErrorMessage,
            macErrorMessage: macErrorMessage,
            lastSimulatorEntry: try await simulatorHistory,
            lastDeviceEntry: try await deviceHistory,
            lastMacEntry: try await macHistory
        )
    }

    /// Maps variant-specific Mac queries to the stored generic Mac history bucket.
    private func macHistoryQueryType(for queryType: DestinationQueryType) -> DestinationQueryType {
        switch queryType {
        case .macOSCatalyst, .macOSDesignedForIPad, .all:
            return .macOS
        default:
            return queryType
        }
    }

    /// Returns true when the whole picker depends on Mac destination loading.
    private func isMacOnlyQuery(_ queryType: DestinationQueryType) -> Bool {
        switch queryType {
        case .macOS, .macOSCatalyst, .macOSDesignedForIPad:
            return true
        default:
            return false
        }
    }
}
