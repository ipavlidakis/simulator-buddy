import Foundation

/// Provides the current host operating system version.
public struct OperatingSystemVersionProvider: Sendable {
    /// Creates a stateless version provider.
    public init() {}

    /// Returns the current macOS version without a trailing `.0` patch.
    public func currentVersion() -> String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        if version.patchVersion > 0 {
            return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        }

        return "\(version.majorVersion).\(version.minorVersion)"
    }
}
