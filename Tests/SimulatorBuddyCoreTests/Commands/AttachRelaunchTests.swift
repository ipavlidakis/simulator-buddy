import Foundation
import Testing
@testable import SimulatorBuddyCore

/// Tests for post-picker attach process replacement.
struct AttachRelaunchTests {
    /// Verifies picker-based attach relaunches with an explicit destination.
    @Test
    func pickedDestination_relaunchesDirectAttachProcess() async throws {
        let rootDirectory = temporaryDirectory()
        let record = DestinationRecord(
            kind: .device,
            udid: "DEVICE-1",
            name: "iPhone Blue",
            runtime: "iOS 26.5",
            state: .connected,
            stateDescription: "Connected"
        )
        let runner = RecordingCommandRunner(results: [])
        let replacer = RecordingProcessReplacer(exitCode: 44)
        let app = CLIApplication(
            fetcher: StaticDestinationFetcher(simulators: [], devices: [record]),
            historyStore: HistoryStore(paths: AppPaths(rootDirectory: rootDirectory)),
            pickerPresenter: StubPickerPresenter(result: .success(record)),
            commandRunner: runner,
            now: { Date(timeIntervalSince1970: 400) },
            currentWorkingDirectory: { URL(fileURLWithPath: "/tmp/workspace", isDirectory: true) },
            standardOutput: { _ in },
            standardError: { _ in },
            processReplacer: replacer,
            executablePath: "/tmp/simulator-buddy"
        )

        let exitCode = await app.run(arguments: [
            "attach",
            "--type", "device",
            "--scope", "custom-scope",
            "--process-name", "StreamVideoCallApp-Debug",
        ])

        #expect(exitCode == 44)
        #expect(await runner.snapshot().isEmpty)
        #expect(replacer.snapshot()?.0 == "/tmp/simulator-buddy")
        #expect(replacer.snapshot()?.1 == [
            "attach",
            "--type", "device",
            "--scope", "custom-scope",
            "--process-name", "StreamVideoCallApp-Debug",
            "--destination", "DEVICE-1",
        ])
    }
}
