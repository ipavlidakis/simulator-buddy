import Foundation
import SimulatorBuddyCore

@main
/// Executable entry point that wires production dependencies and runs the CLI.
struct SimulatorBuddyExecutable {
    /// Builds the app graph, executes the command, and exits with its status.
    static func main() async {
        let paths = AppPaths()
        let commandRunner = ProcessCommandRunner()
        let fetcher = SystemDestinationFetcher(runner: commandRunner)
        let historyStore = HistoryStore(paths: paths)
        let cacheStore = DestinationCacheStore(paths: paths)
        let pickerPresenter = NativePickerPresenter(
            fetcher: fetcher,
            cacheStore: cacheStore,
            historyStore: historyStore
        )

        let application = CLIApplication(
            fetcher: fetcher,
            historyStore: historyStore,
            pickerPresenter: pickerPresenter,
            commandRunner: commandRunner,
            macRunDirectory: paths.macRunDirectory,
            currentWorkingDirectory: {
                URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
            },
            standardOutput: {
                print($0)
            },
            standardError: { message in
                FileHandle.standardError.write(Data((message + "\n").utf8))
            },
            streamStandardOutput: { chunk in
                FileHandle.standardOutput.write(Data(chunk.utf8))
            },
            streamStandardError: { chunk in
                FileHandle.standardError.write(Data(chunk.utf8))
            },
            processReplacer: POSIXProcessReplacer(),
            executablePath: Bundle.main.executablePath ?? CommandLine.arguments[0]
        )

        let status = await application.run(arguments: Array(CommandLine.arguments.dropFirst()))
        Foundation.exit(status)
    }
}
