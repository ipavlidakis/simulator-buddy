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
        let macTime = Date(timeIntervalSince1970: 30)

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

        _ = try await store.update(
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

        let snapshot = try await store.update(
            kind: .macOS,
            records: [
                DestinationRecord(
                    kind: .macOS,
                    udid: "MAC-1",
                    name: "MacBook Pro",
                    runtime: "macOS 15.5",
                    state: .available,
                    stateDescription: "Available"
                ),
            ],
            fetchedAt: macTime
        )

        let reloaded = try await store.load()

        #expect(snapshot.simulators.map(\.udid) == ["SIM-1"])
        #expect(snapshot.devices.map(\.udid) == ["DEVICE-1"])
        #expect(snapshot.macs.map(\.udid) == ["MAC-1"])
        #expect(snapshot.simulatorFetchedAt == simulatorTime)
        #expect(snapshot.deviceFetchedAt == deviceTime)
        #expect(snapshot.macFetchedAt == macTime)
        #expect(reloaded == snapshot)
    }

    @Test
    func load_decodesCacheSnapshotsWithoutMacFields() async throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let paths = AppPaths(rootDirectory: rootDirectory)
        try FileManager.default.createDirectory(
            at: paths.cacheDirectory,
            withIntermediateDirectories: true
        )
        try """
        {
          "schemaVersion" : 1,
          "simulators" : [],
          "devices" : []
        }
        """.write(to: paths.destinationCacheFile, atomically: true, encoding: .utf8)

        let snapshot = try await DestinationCacheStore(paths: paths).load()

        #expect(snapshot.macs.isEmpty)
        #expect(snapshot.macFetchedAt == nil)
    }
}
