import Foundation
import Testing
@testable import SimulatorBuddyCore

struct CLIApplicationTests {
    @Test
    func list_json_outputsLiveDestinations() async throws {
        let stdout = OutputRecorder()
        let stderr = OutputRecorder()
        let record = DestinationRecord(
            kind: .simulator,
            udid: "SIM-1",
            name: "iPhone Air",
            runtime: "iOS 26.5",
            state: .booted,
            stateDescription: "Booted"
        )

        let app = CLIApplication(
            fetcher: StaticDestinationFetcher(simulators: [record], devices: []),
            historyStore: HistoryStore(paths: AppPaths(rootDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))),
            pickerPresenter: StubPickerPresenter(result: .success(record)),
            currentWorkingDirectory: { URL(fileURLWithPath: "/tmp", isDirectory: true) },
            standardOutput: { stdout.write($0) },
            standardError: { stderr.write($0) }
        )

        let exitCode = await app.run(arguments: ["list", "--type", "simulator", "--format", "json"])

        #expect(exitCode == 0)
        #expect(stderr.snapshot().isEmpty)
        #expect(stdout.snapshot().joined().contains("\"udid\" : \"SIM-1\""))
    }

    @Test
    func last_udid_resolvesScopedHistoryAgainstLiveRecords() async throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let historyStore = HistoryStore(paths: AppPaths(rootDirectory: rootDirectory))
        let scope = SelectionScope.explicit("workspace")
        let record = DestinationRecord(
            kind: .device,
            udid: "DEVICE-1",
            name: "iPhone Blue",
            runtime: "iOS 26.4",
            state: .connected,
            stateDescription: "Connected"
        )

        try await historyStore.record(
            selection: ResolvedSelection(
                destination: record,
                scope: scope,
                selectedAt: Date(timeIntervalSince1970: 100)
            )
        )

        let stdout = OutputRecorder()
        let app = CLIApplication(
            fetcher: StaticDestinationFetcher(simulators: [], devices: [record]),
            historyStore: historyStore,
            pickerPresenter: StubPickerPresenter(result: .success(record)),
            currentWorkingDirectory: { URL(fileURLWithPath: "/tmp", isDirectory: true) },
            standardOutput: { stdout.write($0) },
            standardError: { _ in }
        )

        let exitCode = await app.run(arguments: ["last", "--type", "device", "--scope", "workspace"])

        #expect(exitCode == 0)
        #expect(stdout.snapshot() == ["DEVICE-1"])
    }

    @Test
    func list_macos_outputsMacDestinations() async throws {
        let stdout = OutputRecorder()
        let stderr = OutputRecorder()
        let record = DestinationRecord(
            kind: .macOS,
            udid: "MAC-UDID-1",
            name: "MacBook Pro",
            runtime: "macOS 15.5",
            state: .available,
            stateDescription: "Available"
        )

        let app = CLIApplication(
            fetcher: StaticDestinationFetcher(simulators: [], devices: [], macs: [record]),
            historyStore: HistoryStore(paths: AppPaths(rootDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))),
            pickerPresenter: StubPickerPresenter(result: .success(record)),
            currentWorkingDirectory: { URL(fileURLWithPath: "/tmp", isDirectory: true) },
            standardOutput: { stdout.write($0) },
            standardError: { stderr.write($0) }
        )

        let exitCode = await app.run(arguments: ["list", "--type", "macos", "--format", "json"])

        #expect(exitCode == 0)
        #expect(stderr.snapshot().isEmpty)
        #expect(stdout.snapshot().joined().contains("\"kind\" : \"macos\""))
        #expect(stdout.snapshot().joined().contains("\"udid\" : \"MAC-UDID-1\""))
    }

    @Test
    func select_cancel_returnsExitCode130() async {
        let stdout = OutputRecorder()
        let stderr = OutputRecorder()
        let app = CLIApplication(
            fetcher: StaticDestinationFetcher(simulators: [], devices: []),
            historyStore: HistoryStore(paths: AppPaths(rootDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))),
            pickerPresenter: StubPickerPresenter(result: .failure(DestinationPickerFailure.cancelled)),
            currentWorkingDirectory: { URL(fileURLWithPath: "/tmp", isDirectory: true) },
            standardOutput: { stdout.write($0) },
            standardError: { stderr.write($0) }
        )

        let exitCode = await app.run(arguments: ["select", "--type", "all"])

        #expect(exitCode == 130)
        #expect(stdout.snapshot().isEmpty)
        #expect(stderr.snapshot().isEmpty)
    }
}
