/// Result of resolving the destination used for build-and-run.
enum BuildDestinationResolution: Sendable {
    /// Destination metadata resolved successfully.
    case success(record: DestinationRecord, source: BuildDestinationSource)

    /// Destination discovery failed with an exit code.
    case failure(Int32)

    /// Shell status represented by this resolution.
    var exitCode: Int32 {
        switch self {
        case .success:
            return 0
        case let .failure(status):
            return status
        }
    }
}
