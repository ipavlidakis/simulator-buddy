import Foundation
import Testing
@testable import SimulatorBuddyCore

/// Tests for post-picker build-and-run process replacement.
struct BuildAndRunRelaunchTests {
    /// Verifies picker selections relaunch the command with an explicit destination.
    @Test
    func xcodeRun_pickerSelectionRelaunchesDirectRunProcess() async throws {
        let rootDirectory = temporaryDirectory()
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
            results: [CommandResult(terminationStatus: 0, stdout: showDestinationsOutput, stderr: "")]
        )
        let replacer = RecordingProcessReplacer(exitCode: 33)
        let app = CLIApplication(
            fetcher: StaticDestinationFetcher(simulators: [], devices: []),
            historyStore: HistoryStore(paths: AppPaths(rootDirectory: rootDirectory)),
            pickerPresenter: StubPickerPresenter(result: .success(selectedRecord)),
            commandRunner: runner,
            currentWorkingDirectory: { rootDirectory },
            standardOutput: { _ in },
            standardError: { _ in },
            processReplacer: replacer,
            executablePath: "/tmp/simulator-buddy"
        )

        let exitCode = await app.run(arguments: runArguments)

        #expect(exitCode == 33)
        #expect(await runner.snapshot() == [
            Command(
                executable: "xcodebuild",
                arguments: ["-project", "/tmp/App.xcodeproj", "-scheme", "App", "-showdestinations"]
            ),
        ])
        #expect(replacer.snapshot()?.0 == "/tmp/simulator-buddy")
        #expect(replacer.snapshot()?.1 == expectedRelaunchArguments)
    }

    /// Arguments used for the first picker-backed command.
    private var runArguments: [String] {
        [
            "run",
            "--type", "simulator",
            "--scope", "custom-scope",
            "--env", "FOO=bar",
            "--log-category", "Video",
            "--log-category", "WebRTC",
            "--bundle-id", "com.example.Override",
            "--skip-install",
            "-project", "/tmp/App.xcodeproj",
            "-scheme", "App",
            "-configuration", "Debug",
        ]
    }

    /// Expected argv for the direct-run replacement process.
    private var expectedRelaunchArguments: [String] {
        [
            "run",
            "--type", "simulator",
            "--scope", "custom-scope",
            "--env", "FOO=bar",
            "--log-category", "Video",
            "--log-category", "WebRTC",
            "--bundle-id", "com.example.Override",
            "--skip-install",
            "--destination", "platform=iOS Simulator,id=SIM-1",
            "-project", "/tmp/App.xcodeproj",
            "-scheme", "App",
            "-configuration", "Debug",
        ]
    }

    /// Sample `xcodebuild -showdestinations` output for relaunch coverage.
    private var showDestinationsOutput: String {
        """
        Available destinations for the "App" scheme:
            { platform:iOS Simulator, arch:arm64, id:SIM-1, OS:26.5, name:iPhone Air }
        """
    }
}
