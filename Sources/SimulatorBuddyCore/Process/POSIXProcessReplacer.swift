import Darwin
import Foundation

/// POSIX `execv` implementation of process replacement.
public final class POSIXProcessReplacer: ProcessReplacing, @unchecked Sendable {
    /// Creates a POSIX process replacer.
    public init() {}

    /// Replaces the current process image and only returns when `execv` fails.
    public func replaceCurrentProcess(executablePath: String, arguments: [String]) throws -> Int32 {
        var cArguments: [UnsafeMutablePointer<CChar>?] = ([executablePath] + arguments).map {
            strdup($0)
        }
        cArguments.append(nil)

        defer {
            for argument in cArguments {
                free(argument)
            }
        }

        execv(executablePath, &cArguments)
        throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
}
