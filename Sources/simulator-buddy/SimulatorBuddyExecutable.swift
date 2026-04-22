import Foundation
import SimulatorBuddyCore

@main
struct SimulatorBuddyExecutable {
    static func main() async {
        let paths = AppPaths()
        let fetcher = SystemDestinationFetcher(runner: ProcessCommandRunner())
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
            currentWorkingDirectory: {
                URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
            },
            standardOutput: {
                print($0)
            },
            standardError: { message in
                FileHandle.standardError.write(Data((message + "\n").utf8))
            }
        )

        let status = await application.run(arguments: Array(CommandLine.arguments.dropFirst()))
        Foundation.exit(status)
    }
}
