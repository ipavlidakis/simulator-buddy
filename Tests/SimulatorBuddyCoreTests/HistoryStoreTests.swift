import Foundation
import Testing
@testable import SimulatorBuddyCore

struct HistoryStoreTests {
    @Test
    func recordSelection_updatesGlobalAndScopedHistory() async throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let paths = AppPaths(rootDirectory: rootDirectory)
        let store = HistoryStore(paths: paths)
        let scope = SelectionScope.explicit("workspace-a")
        let selection = ResolvedSelection(
            destination: DestinationRecord(
                kind: .simulator,
                udid: "SIM-1",
                name: "iPhone Air",
                runtime: "iOS 26.5",
                state: .booted,
                stateDescription: "Booted"
            ),
            scope: scope,
            selectedAt: Date(timeIntervalSince1970: 1_234)
        )

        try await store.record(selection: selection)

        let globalHistory = try await store.loadGlobal()
        let scopedHistory = try await store.loadScope(scope)

        #expect(globalHistory.lastSimulator?.udid == "SIM-1")
        #expect(globalHistory.lastAny?.udid == "SIM-1")
        #expect(scopedHistory.lastSimulator?.udid == "SIM-1")
        #expect(scopedHistory.lastAny?.udid == "SIM-1")
    }

    @Test
    func resolveLast_prefersScopedHistoryAndFallsBackToGlobal() async throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let paths = AppPaths(rootDirectory: rootDirectory)
        let store = HistoryStore(paths: paths)
        let scope = SelectionScope.explicit("workspace-a")

        let globalSelection = ResolvedSelection(
            destination: DestinationRecord(
                kind: .device,
                udid: "DEVICE-GLOBAL",
                name: "iPhone Blue",
                runtime: "iOS 26.4",
                state: .connected,
                stateDescription: "Connected"
            ),
            scope: nil,
            selectedAt: Date(timeIntervalSince1970: 100)
        )
        try await store.record(selection: globalSelection)

        let scopedSelection = ResolvedSelection(
            destination: DestinationRecord(
                kind: .simulator,
                udid: "SIM-SCOPED",
                name: "iPhone Air",
                runtime: "iOS 26.5",
                state: .booted,
                stateDescription: "Booted"
            ),
            scope: scope,
            selectedAt: Date(timeIntervalSince1970: 200)
        )
        try await store.record(selection: scopedSelection)

        let scopedSimulator = try await store.resolveLast(type: .simulator, scope: scope)
        let scopedAll = try await store.resolveLast(type: .all, scope: scope)
        let globalDevice = try await store.resolveLast(type: .device, scope: scope)

        #expect(scopedSimulator?.udid == "SIM-SCOPED")
        #expect(scopedAll?.udid == "SIM-SCOPED")
        #expect(globalDevice?.udid == "DEVICE-GLOBAL")
    }
}
