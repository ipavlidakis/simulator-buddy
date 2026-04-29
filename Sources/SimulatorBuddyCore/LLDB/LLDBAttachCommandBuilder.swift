import Foundation

/// Builds LLDB command files for attaching to simulator, device, or Mac processes.
struct LLDBAttachCommandBuilder {
    /// Writes an LLDB script that attaches to the named process on the destination.
    func writeCommandFile(
        at url: URL,
        destination: DestinationRecord,
        processName: String
    ) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let body = commands(for: destination, processName: processName).joined(separator: "\n") + "\n"
        try body.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Returns LLDB commands for selecting the destination and attaching by process name.
    func commands(for destination: DestinationRecord, processName: String) -> [String] {
        switch destination.kind {
        case .simulator:
            return [
                "platform select ios-simulator",
                "process attach --name \(quoted(processName)) --waitfor --include-existing",
            ]
        case .device:
            return [
                "device select \(destination.udid)",
                "device process attach --name \(quoted(processName)) --waitfor --include-existing",
            ]
        case .macOS:
            return [
                "process attach --name \(quoted(processName)) --waitfor --include-existing",
            ]
        }
    }

    /// Quotes and escapes an LLDB argument while preserving spaces in process names.
    private func quoted(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
