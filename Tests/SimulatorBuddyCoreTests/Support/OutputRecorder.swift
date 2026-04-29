import Synchronization

/// Thread-safe recorder for stdout and stderr chunks in tests.
final class OutputRecorder: Sendable {
    /// Locked output chunks in write order.
    private let values = Mutex([String]())

    /// Records one output chunk.
    func write(_ value: String) {
        values.withLock {
            $0.append(value)
        }
    }

    /// Returns all recorded chunks.
    func snapshot() -> [String] {
        values.withLock { $0 }
    }
}
