import Foundation
import Testing
@testable import SimulatorBuddyCore

struct DestinationCacheStoreTests {
    @Test
    func update_mergesPerSourceRecordsAndPersistsFetchTimestamps() async throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let paths = AppPaths(rootDirectory: rootDirectory)
        let store = DestinationCacheStore(paths: paths)

        let simulatorTime = Date(timeIntervalSince1970: 10)
        let deviceTime = Date(timeIntervalSince1970: 20)

        _ = try await store.update(
            kind: .simulator,
            records: [
                DestinationRecord(
                    kind: .simulator,
                    udid: "SIM-1",
                    name: "iPhone Air",
                    runtime: "iOS 26.5",
                    state: .booted,
                    stateDescription: "Booted"
                ),
            ],
            fetchedAt: simulatorTime
        )

        let snapshot = try await store.update(
            kind: .device,
            records: [
                DestinationRecord(
                    kind: .device,
                    udid: "DEVICE-1",
                    name: "iPhone Blue",
                    runtime: "iOS 26.4",
                    state: .connected,
                    stateDescription: "Connected"
                ),
            ],
            fetchedAt: deviceTime
        )

        let reloaded = try await store.load()

        #expect(snapshot.simulators.map(\.udid) == ["SIM-1"])
        #expect(snapshot.devices.map(\.udid) == ["DEVICE-1"])
        #expect(snapshot.simulatorFetchedAt == simulatorTime)
        #expect(snapshot.deviceFetchedAt == deviceTime)
        #expect(reloaded == snapshot)
    }
}
