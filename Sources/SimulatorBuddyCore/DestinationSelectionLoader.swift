import Foundation

public struct LoadedDestinationSelection: Sendable {
    public let queryType: DestinationQueryType
    public let scope: SelectionScope?
    public let simulatorRecords: [DestinationRecord]
    public let deviceRecords: [DestinationRecord]
    public let macRecords: [DestinationRecord]
    public let simulatorErrorMessage: String?
    public let deviceErrorMessage: String?
    public let macErrorMessage: String?
    public let lastSimulatorEntry: HistoryEntry?
    public let lastDeviceEntry: HistoryEntry?
    public let lastMacEntry: HistoryEntry?

    public init(
        queryType: DestinationQueryType,
        scope: SelectionScope?,
        simulatorRecords: [DestinationRecord],
        deviceRecords: [DestinationRecord],
        macRecords: [DestinationRecord],
        simulatorErrorMessage: String?,
        deviceErrorMessage: String?,
        macErrorMessage: String?,
        lastSimulatorEntry: HistoryEntry?,
        lastDeviceEntry: HistoryEntry?,
        lastMacEntry: HistoryEntry?
    ) {
        self.queryType = queryType
        self.scope = scope
        self.simulatorRecords = simulatorRecords
        self.deviceRecords = deviceRecords
        self.macRecords = macRecords
        self.simulatorErrorMessage = simulatorErrorMessage
        self.deviceErrorMessage = deviceErrorMessage
        self.macErrorMessage = macErrorMessage
        self.lastSimulatorEntry = lastSimulatorEntry
        self.lastDeviceEntry = lastDeviceEntry
        self.lastMacEntry = lastMacEntry
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
        async let macHistory = queryType.includes(.macOS)
            ? historyStore.resolveLast(type: .macOS, scope: scope)
            : nil

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
                macRecords = try await fetcher.fetchMacs()
                _ = try? await cacheStore.update(
                    kind: .macOS,
                    records: macRecords,
                    fetchedAt: now()
                )
            } catch {
                macErrorMessage = error.localizedDescription
                if queryType == .macOS {
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
}
