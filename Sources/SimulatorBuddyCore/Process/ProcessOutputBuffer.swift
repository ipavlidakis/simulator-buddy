import Foundation
import Synchronization

/// Thread-safe process output byte accumulator.
final class ProcessOutputBuffer: @unchecked Sendable {
    /// Protected output data collected from one pipe.
    private let data = Mutex(Data())

    /// Creates an empty output buffer.
    init() {}

    /// Appends a chunk when the pipe produced bytes.
    func append(_ chunk: Data) {
        guard chunk.isEmpty == false else {
            return
        }

        data.withLock { output in
            output.append(chunk)
        }
    }

    /// Decodes all buffered bytes as UTF-8 text.
    func string() -> String {
        data.withLock { output in
            String(decoding: output, as: UTF8.self)
        }
    }
}
