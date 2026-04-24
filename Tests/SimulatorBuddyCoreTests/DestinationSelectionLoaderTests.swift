import Foundation
import Testing
@testable import SimulatorBuddyCore

struct DestinationSelectionLoaderTests {
    @Test
    func load_fetchesLiveRecords_updatesCache_andReturnsHistory() async throws {
        let simulator = DestinationRecord(
            kind: .simulator,
            udid: "SIM-1",
            name: "iPhone Air",
            runtime: "iOS 26.5",
            state: .booted,
            stateDescription: "Booted"
        )
        let device = DestinationRecord(
            kind: .device,
            udid: "DEVICE-1",
            name: "iPhone Blue",
            runtime: "iOS 26.4",
            state: .connected,
            stateDescription: "Connected"
        )
        let mac = DestinationRecord(
            kind: .macOS,
            udid: "MAC-1",
            name: "MacBook Pro",
            runtime: "macOS 15.5",
            state: .available,
            stateDescription: "Available"
        )

        let cacheStore = InMemoryCacheStore()
        let historyStore = StubHistoryProvider(
            simulatorEntry: HistoryEntry(
                kind: .simulator,
                udid: "SIM-1",
                name: "iPhone Air",
                runtime: "iOS 26.5",
                selectedAt: Date(timeIntervalSince1970: 10)
            ),
            deviceEntry: HistoryEntry(
                kind: .device,
                udid: "DEVICE-1",
                name: "iPhone Blue",
                runtime: "iOS 26.4",
                selectedAt: Date(timeIntervalSince1970: 20)
            ),
            macEntry: HistoryEntry(
                kind: .macOS,
                udid: "MAC-1",
                name: "MacBook Pro",
                runtime: "macOS 15.5",
                selectedAt: Date(timeIntervalSince1970: 30)
            )
        )
        let loader = DestinationSelectionLoader(
            fetcher: StaticDestinationFetcher(simulators: [simulator], devices: [device], macs: [mac]),
            cacheStore: cacheStore,
            historyStore: historyStore,
            now: { Date(timeIntervalSince1970: 123) }
        )

        let loaded = try await loader.load(
            queryType: .all,
            scope: SelectionScope.explicit("workspace")
        )
        let cache = try await cacheStore.load()

        #expect(loaded.simulatorRecords == [simulator])
        #expect(loaded.deviceRecords == [device])
        #expect(loaded.macRecords == [mac])
        #expect(loaded.lastSimulatorEntry?.udid == "SIM-1")
        #expect(loaded.lastDeviceEntry?.udid == "DEVICE-1")
        #expect(loaded.lastMacEntry?.udid == "MAC-1")
        #expect(cache.simulators == [simulator])
        #expect(cache.devices == [device])
        #expect(cache.macs == [mac])
    }
}
