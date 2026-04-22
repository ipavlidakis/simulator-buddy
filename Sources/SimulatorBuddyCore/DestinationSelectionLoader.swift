import Foundation

public struct LoadedDestinationSelection: Sendable {
    public let queryType: DestinationQueryType
    public let scope: SelectionScope?
    public let simulatorRecords: [DestinationRecord]
    public let deviceRecords: [DestinationRecord]
    public let simulatorErrorMessage: String?
    public let deviceErrorMessage: String?
    public let lastSimulatorEntry: HistoryEntry?
    public let lastDeviceEntry: HistoryEntry?

    public init(
        queryType: DestinationQueryType,
        scope: SelectionScope?,
        simulatorRecords: [DestinationRecord],
        deviceRecords: [DestinationRecord],
        simulatorErrorMessage: String?,
        deviceErrorMessage: String?,
        lastSimulatorEntry: HistoryEntry?,
        lastDeviceEntry: HistoryEntry?
    ) {
        self.queryType = queryType
        self.scope = scope
        self.simulatorRecords = simulatorRecords
        self.deviceRecords = deviceRecords
        self.simulatorErrorMessage = simulatorErrorMessage
        self.deviceErrorMessage = deviceErrorMessage
        self.lastSimulatorEntry = lastSimulatorEntry
        self.lastDeviceEntry = lastDeviceEntry
    }
}

public final class DestinationSelectionLoader: @unchecked Sendable {
    private let fetcher: any DestinationFetching
    private let cacheStore: any DestinationCacheStoring
    private let historyStore: any HistoryProviding
    private let now: @Sendable () -> Date

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

    public func load(
        queryType: DestinationQueryType,
        scope: SelectionScope?
    ) async throws -> LoadedDestinationSelection {
        async let simulatorHistory = queryType.includes(.simulator)
            ? historyStore.resolveLast(type: .simulator, scope: scope)
            : nil
        async let deviceHistory = queryType.includes(.device)
            ? historyStore.resolveLast(type: .device, scope: scope)
            : nil

        var simulatorRecords: [DestinationRecord] = []
        var deviceRecords: [DestinationRecord] = []
        var simulatorErrorMessage: String?
        var deviceErrorMessage: String?

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

        if queryType == .all, simulatorRecords.isEmpty, deviceRecords.isEmpty {
            throw SimulatorBuddyError.noDestinations(.all)
        }

        return LoadedDestinationSelection(
            queryType: queryType,
            scope: scope,
            simulatorRecords: simulatorRecords,
            deviceRecords: deviceRecords,
            simulatorErrorMessage: simulatorErrorMessage,
            deviceErrorMessage: deviceErrorMessage,
            lastSimulatorEntry: try await simulatorHistory,
            lastDeviceEntry: try await deviceHistory
        )
    }
}
