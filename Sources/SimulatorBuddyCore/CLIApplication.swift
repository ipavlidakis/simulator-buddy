import Foundation

public protocol PickerPresenting: Sendable {
    func present(queryType: DestinationQueryType, scope: SelectionScope?) async throws -> DestinationRecord
}

public final class CLIApplication: @unchecked Sendable {
    private let fetcher: any DestinationFetching
    private let historyStore: HistoryStore
    private let pickerPresenter: any PickerPresenting
    private let now: @Sendable () -> Date
    private let currentWorkingDirectory: @Sendable () -> URL
    private let standardOutput: @Sendable (String) -> Void
    private let standardError: @Sendable (String) -> Void
    private let encoder: JSONEncoder

    public init(
        fetcher: any DestinationFetching,
        historyStore: HistoryStore,
        pickerPresenter: any PickerPresenting,
        now: @escaping @Sendable () -> Date = Date.init,
        currentWorkingDirectory: @escaping @Sendable () -> URL,
        standardOutput: @escaping @Sendable (String) -> Void,
        standardError: @escaping @Sendable (String) -> Void
    ) {
        self.fetcher = fetcher
        self.historyStore = historyStore
        self.pickerPresenter = pickerPresenter
        self.now = now
        self.currentWorkingDirectory = currentWorkingDirectory
        self.standardOutput = standardOutput
        self.standardError = standardError

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    public func run(arguments: [String]) async -> Int32 {
        do {
            let parsed = try parse(arguments: arguments)

            switch parsed {
            case .help:
                standardOutput(Self.usage)
                return 0
            case let .list(type, format):
                try await runList(type: type, format: format)
                return 0
            case let .last(type, scope, format):
                try await runLast(type: type, scope: scope, format: format)
                return 0
            case let .select(type, scope, format):
                try await runSelect(type: type, scope: scope, format: format)
                return 0
            case let .debug(type, scope, processName, lldbCommandFile):
                try await runDebug(
                    type: type,
                    scope: scope,
                    processName: processName,
                    lldbCommandFile: lldbCommandFile
                )
                return 0
            }
        } catch let failure as DestinationPickerFailure {
            switch failure {
            case .cancelled:
                return 130
            default:
                standardError(failure.localizedDescription)
                return 1
            }
        } catch {
            standardError(error.localizedDescription)
            return 1
        }
    }

    private func runList(type: DestinationQueryType, format: SelectOutputFormat) async throws {
        let records = try await fetchRecords(for: type)
        guard records.isEmpty == false else {
            throw SimulatorBuddyError.noDestinations(type)
        }

        switch format {
        case .json:
            standardOutput(try encodeJSON(records))
        case .table:
            standardOutput(renderTable(records))
        case .udid:
            throw SimulatorBuddyError.usage("`list` supports only `table` and `json` formats.")
        }
    }

    private func runLast(
        type: DestinationQueryType,
        scope: SelectionScope,
        format: SelectOutputFormat
    ) async throws {
        guard let historyEntry = try await historyStore.resolveLast(type: type, scope: scope) else {
            throw SimulatorBuddyError.noHistory(type)
        }

        let records = try await fetchRecords(for: type)
        guard let record = records.first(where: { $0.udid == historyEntry.udid }) else {
            throw SimulatorBuddyError.historyDestinationUnavailable(historyEntry.udid)
        }

        let resolvedSelection = ResolvedSelection(
            destination: record,
            scope: scope,
            selectedAt: historyEntry.selectedAt
        )

        try output(selection: resolvedSelection, format: format)
    }

    private func runSelect(
        type: DestinationQueryType,
        scope: SelectionScope,
        format: SelectOutputFormat
    ) async throws {
        let record = try await pickerPresenter.present(queryType: type, scope: scope)
        let selection = ResolvedSelection(destination: record, scope: scope, selectedAt: now())
        try await historyStore.record(selection: selection)
        try output(selection: selection, format: format)
    }

    private func runDebug(
        type: DestinationQueryType,
        scope: SelectionScope,
        processName: String,
        lldbCommandFile: String
    ) async throws {
        let record = try await pickerPresenter.present(queryType: type, scope: scope)
        let selectedAt = now()
        let selection = ResolvedSelection(destination: record, scope: scope, selectedAt: selectedAt)
        try await historyStore.record(selection: selection)

        let commandFileURL = URL(fileURLWithPath: lldbCommandFile)
        try FileManager.default.createDirectory(
            at: commandFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let commands = lldbAttachCommands(for: record, processName: processName)
            .joined(separator: "\n") + "\n"
        try commands.write(to: commandFileURL, atomically: true, encoding: .utf8)

        standardOutput(
            try encodeJSON(
                DebugConnection(
                    destination: record,
                    scope: scope,
                    selectedAt: selectedAt,
                    lldbCommandFile: commandFileURL.path
                )
            )
        )
    }

    private func lldbAttachCommands(
        for destination: DestinationRecord,
        processName: String
    ) -> [String] {
        switch destination.kind {
        case .simulator:
            return [
                "platform select ios-simulator",
                "process attach --name \(lldbQuoted(processName)) --waitfor --include-existing",
            ]
        case .device:
            return [
                "device select \(destination.udid)",
                "device process attach --name \(lldbQuoted(processName)) --waitfor --include-existing",
            ]
        case .macOS:
            return [
                "process attach --name \(lldbQuoted(processName)) --waitfor --include-existing",
            ]
        }
    }

    private func lldbQuoted(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private func fetchRecords(for type: DestinationQueryType) async throws -> [DestinationRecord] {
        switch type {
        case .simulator:
            return try await fetcher.fetchSimulators()
        case .device:
            return try await fetcher.fetchDevices()
        case .macOS:
            return try await fetcher.fetchMacs()
        case .all:
            async let simulators = fetcher.fetchSimulators()
            async let devices = fetcher.fetchDevices()
            async let macs = fetcher.fetchMacs()
            return try await (simulators + devices + macs)
                .sorted { lhs, rhs in
                    if lhs.kind != rhs.kind {
                        return lhs.kind.rawValue < rhs.kind.rawValue
                    }

                    return lhs.sortKey < rhs.sortKey
                }
        }
    }

    private func output(selection: ResolvedSelection, format: SelectOutputFormat) throws {
        switch format {
        case .udid:
            standardOutput(selection.destination.udid)
        case .json:
            standardOutput(try encodeJSON(selection))
        case .table:
            throw SimulatorBuddyError.usage("`select` and `last` support only `udid` and `json` formats.")
        }
    }

    private func encodeJSON<T: Encodable>(_ value: T) throws -> String {
        String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    private func renderTable(_ records: [DestinationRecord]) -> String {
        let headers = ["KIND", "NAME", "RUNTIME", "STATE", "UDID"]
        let rows = records.map {
            [
                $0.kind.rawValue,
                $0.name,
                $0.runtime ?? "-",
                $0.stateDescription,
                $0.udid,
            ]
        }

        var widths = headers.map(\.count)
        for row in rows {
            for (index, cell) in row.enumerated() {
                widths[index] = max(widths[index], cell.count)
            }
        }

        let headerLine = zip(headers, widths)
            .map { header, width in header.padding(toLength: width, withPad: " ", startingAt: 0) }
            .joined(separator: "  ")
        let separatorLine = widths
            .map { String(repeating: "-", count: $0) }
            .joined(separator: "  ")
        let dataLines = rows.map { row in
            zip(row, widths)
                .map { cell, width in cell.padding(toLength: width, withPad: " ", startingAt: 0) }
                .joined(separator: "  ")
        }

        return ([headerLine, separatorLine] + dataLines).joined(separator: "\n")
    }

    private func parse(arguments: [String]) throws -> ParsedCommand {
        guard let commandName = arguments.first else {
            return .help
        }

        if commandName == "--help" || commandName == "-h" {
            return .help
        }

        var type: DestinationQueryType?
        var format: SelectOutputFormat?
        var scope: SelectionScope?
        var processName: String?
        var lldbCommandFile: String?
        var index = 1

        while index < arguments.count {
            switch arguments[index] {
            case "--type":
                index += 1
                type = try parseType(arguments, index: index)
            case "--format":
                index += 1
                format = try parseFormat(arguments, index: index)
            case "--scope":
                index += 1
                scope = SelectionScope.explicit(try parseValue(arguments, index: index, option: "--scope"))
            case "--process-name":
                index += 1
                processName = try parseValue(arguments, index: index, option: "--process-name")
            case "--lldb-command-file":
                index += 1
                lldbCommandFile = try parseValue(arguments, index: index, option: "--lldb-command-file")
            case "--help", "-h":
                return .help
            default:
                throw SimulatorBuddyError.usage("Unknown argument: \(arguments[index])")
            }

            index += 1
        }

        let resolvedType = type ?? .all
        let resolvedScope = scope ?? SelectionScope.automatic(workingDirectory: currentWorkingDirectory())

        switch commandName {
        case "list":
            return .list(type: resolvedType, format: format ?? .table)
        case "last":
            return .last(type: resolvedType, scope: resolvedScope, format: format ?? .udid)
        case "select":
            return .select(type: resolvedType, scope: resolvedScope, format: format ?? .udid)
        case "debug":
            guard let processName, processName.isEmpty == false else {
                throw SimulatorBuddyError.usage("Missing value for --process-name")
            }
            guard let lldbCommandFile, lldbCommandFile.isEmpty == false else {
                throw SimulatorBuddyError.usage("Missing value for --lldb-command-file")
            }
            return .debug(
                type: resolvedType,
                scope: resolvedScope,
                processName: processName,
                lldbCommandFile: lldbCommandFile
            )
        default:
            throw SimulatorBuddyError.usage("Unknown command: \(commandName)")
        }
    }

    private func parseType(_ arguments: [String], index: Int) throws -> DestinationQueryType {
        let value = try parseValue(arguments, index: index, option: "--type")
        guard let type = DestinationQueryType(rawValue: value) else {
            throw SimulatorBuddyError.usage("Unsupported type: \(value)")
        }

        return type
    }

    private func parseFormat(_ arguments: [String], index: Int) throws -> SelectOutputFormat {
        let value = try parseValue(arguments, index: index, option: "--format")
        guard let format = SelectOutputFormat(rawValue: value) else {
            throw SimulatorBuddyError.usage("Unsupported format: \(value)")
        }

        return format
    }

    private func parseValue(_ arguments: [String], index: Int, option: String) throws -> String {
        guard arguments.indices.contains(index) else {
            throw SimulatorBuddyError.usage("Missing value for \(option)")
        }

        return arguments[index]
    }

    private enum ParsedCommand {
        case help
        case list(type: DestinationQueryType, format: SelectOutputFormat)
        case last(type: DestinationQueryType, scope: SelectionScope, format: SelectOutputFormat)
        case select(type: DestinationQueryType, scope: SelectionScope, format: SelectOutputFormat)
        case debug(
            type: DestinationQueryType,
            scope: SelectionScope,
            processName: String,
            lldbCommandFile: String
        )
    }

    private struct DebugConnection: Encodable {
        let destination: DestinationRecord
        let scope: SelectionScope?
        let selectedAt: Date
        let lldbCommandFile: String
    }

    private enum SelectOutputFormat: String {
        case udid
        case json
        case table
    }

    static let usage = """
    Usage:
      simulator-buddy list [--type simulator|device|macos|all] [--format table|json]
      simulator-buddy last [--type simulator|device|macos|all] [--scope <key>] [--format udid|json]
      simulator-buddy select [--type simulator|device|macos|all] [--scope <key>] [--format udid|json]
      simulator-buddy debug --process-name <name> --lldb-command-file <path> [--type simulator|device|macos|all] [--scope <key>]
    """
}
