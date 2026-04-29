/// Replaces the current process image with another executable.
public protocol ProcessReplacing: Sendable {
    /// Executes a replacement process with inherited environment.
    func replaceCurrentProcess(executablePath: String, arguments: [String]) throws -> Int32
}
