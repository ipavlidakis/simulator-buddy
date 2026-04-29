import Foundation
import Testing
@testable import SimulatorBuddyCore

/// Tests for raw xcodebuild wrapper mode.
struct XcodebuildWrapperCommandTests {
    /// Verifies selected destination is injected and real xcodebuild status/output is forwarded.
    @Test
    func injectsPickedDestinationAndReturnsXcodebuildStatus() async throws {
        let stdout = OutputRecorder()
        let stderr = OutputRecorder()
        let selectedRecord = DestinationRecord(
            kind: .simulator,
            udid: "SIM-1",
            name: "iPhone Air",
            runtime: "iOS 26.5",
            state: .available,
            stateDescription: "Available",
            xcodeDestinationSpecifier: "platform=iOS Simulator,id=SIM-1"
        )
        let runner = RecordingCommandRunner(
            results: [
                CommandResult(
                    terminationStatus: 0,
                    stdout: """
                    Available destinations for the "App" scheme:
                        { platform:iOS Simulator, arch:arm64, id:SIM-1, OS:26.5, name:iPhone Air }
                        { platform:iOS, arch:arm64, id:DEVICE-1, name:iPhone Blue }
                    """,
                    stderr: ""
                ),
                CommandResult(terminationStatus: 65, stdout: "build out", stderr: "build err"),
            ]
        )
        let picker = StubPickerPresenter(result: .success(selectedRecord))
        let app = CLIApplication(
            fetcher: StaticDestinationFetcher(simulators: [], devices: []),
            historyStore: HistoryStore(paths: AppPaths(rootDirectory: temporaryDirectory())),
            pickerPresenter: picker,
            commandRunner: runner,
            currentWorkingDirectory: { URL(fileURLWithPath: "/tmp", isDirectory: true) },
            standardOutput: { stdout.write($0) },
            standardError: { stderr.write($0) },
            streamStandardOutput: { stdout.write($0) },
            streamStandardError: { stderr.write($0) }
        )

        let exitCode = await app.run(
            arguments: ["-workspace", "/tmp/App.xcworkspace", "-scheme", "App", "test"]
        )

        let commands = await runner.snapshot()
        #expect(exitCode == 65)
        #expect(commands == [
            Command(
                executable: "xcodebuild",
                arguments: ["-workspace", "/tmp/App.xcworkspace", "-scheme", "App", "-showdestinations"]
            ),
            Command(
                executable: "xcodebuild",
                arguments: [
                    "-workspace", "/tmp/App.xcworkspace",
                    "-scheme", "App",
                    "-destination", "platform=iOS Simulator,id=SIM-1",
                    "test",
                ]
            ),
        ])
        #expect(await picker.presentedRecords?.map(\.udid) == ["SIM-1", "DEVICE-1"])
        #expect(stdout.snapshot().contains("build out"))
        #expect(stderr.snapshot().contains("build err"))
    }

    /// Verifies existing `-destination` arguments bypass picker and discovery.
    @Test
    func existingDestination_passesThroughWithoutPicker() async {
        let runner = RecordingCommandRunner(
            results: [CommandResult(terminationStatus: 0, stdout: "", stderr: "")]
        )
        let picker = StubPickerPresenter(result: .failure(DestinationPickerFailure.cancelled))
        let app = CLIApplication(
            fetcher: StaticDestinationFetcher(simulators: [], devices: []),
            historyStore: HistoryStore(paths: AppPaths(rootDirectory: temporaryDirectory())),
            pickerPresenter: picker,
            commandRunner: runner,
            currentWorkingDirectory: { URL(fileURLWithPath: "/tmp", isDirectory: true) },
            standardOutput: { _ in },
            standardError: { _ in }
        )

        let exitCode = await app.run(
            arguments: [
                "-workspace", "/tmp/App.xcworkspace",
                "-scheme", "App",
                "-destination", "id=SIM-1",
                "test",
            ]
        )

        #expect(exitCode == 0)
        #expect(await runner.snapshot() == [
            Command(
                executable: "xcodebuild",
                arguments: [
                    "-workspace", "/tmp/App.xcworkspace",
                    "-scheme", "App",
                    "-destination", "id=SIM-1",
                    "test",
                ]
            ),
        ])
        #expect(await picker.presentCallCount == 0)
    }

    /// Verifies missing scheme bypasses picker and passes through unchanged.
    @Test
    func missingScheme_passesThroughWithoutPicker() async {
        let runner = RecordingCommandRunner(
            results: [CommandResult(terminationStatus: 0, stdout: "", stderr: "")]
        )
        let picker = StubPickerPresenter(result: .failure(DestinationPickerFailure.cancelled))
        let app = CLIApplication(
            fetcher: StaticDestinationFetcher(simulators: [], devices: []),
            historyStore: HistoryStore(paths: AppPaths(rootDirectory: temporaryDirectory())),
            pickerPresenter: picker,
            commandRunner: runner,
            currentWorkingDirectory: { URL(fileURLWithPath: "/tmp", isDirectory: true) },
            standardOutput: { _ in },
            standardError: { _ in }
        )

        let exitCode = await app.run(arguments: ["-workspace", "/tmp/App.xcworkspace", "test"])

        #expect(exitCode == 0)
        #expect(await runner.snapshot() == [
            Command(executable: "xcodebuild", arguments: ["-workspace", "/tmp/App.xcworkspace", "test"]),
        ])
        #expect(await picker.presentCallCount == 0)
    }

    /// Verifies info-only xcodebuild commands bypass picker and pass through unchanged.
    @Test
    func infoCommand_passesThroughWithoutPicker() async {
        let runner = RecordingCommandRunner(
            results: [CommandResult(terminationStatus: 0, stdout: "", stderr: "")]
        )
        let picker = StubPickerPresenter(result: .failure(DestinationPickerFailure.cancelled))
        let app = CLIApplication(
            fetcher: StaticDestinationFetcher(simulators: [], devices: []),
            historyStore: HistoryStore(paths: AppPaths(rootDirectory: temporaryDirectory())),
            pickerPresenter: picker,
            commandRunner: runner,
            currentWorkingDirectory: { URL(fileURLWithPath: "/tmp", isDirectory: true) },
            standardOutput: { _ in },
            standardError: { _ in }
        )

        let exitCode = await app.run(
            arguments: [
                "-workspace", "/tmp/App.xcworkspace",
                "-scheme", "App",
                "-showBuildSettings",
            ]
        )

        #expect(exitCode == 0)
        #expect(await runner.snapshot() == [
            Command(
                executable: "xcodebuild",
                arguments: [
                    "-workspace", "/tmp/App.xcworkspace",
                    "-scheme", "App",
                    "-showBuildSettings",
                ]
            ),
        ])
        #expect(await picker.presentCallCount == 0)
    }
}
