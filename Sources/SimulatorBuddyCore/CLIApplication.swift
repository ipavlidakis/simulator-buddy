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
    """
}
