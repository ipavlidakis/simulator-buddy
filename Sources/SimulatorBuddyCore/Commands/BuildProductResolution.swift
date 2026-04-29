/// Result of resolving a built app product from Xcode metadata.
enum BuildProductResolution: Sendable {
    /// Product metadata resolved successfully.
    case success(BuiltProduct)

    /// Product lookup command failed with an exit code.
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
