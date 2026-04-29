import Foundation

/// Renders destination records as a fixed-width plain text table.
struct DestinationTableRenderer {
    /// Creates a table including headers, separator, and one row per destination.
    func render(records: [DestinationRecord]) -> String {
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
}
