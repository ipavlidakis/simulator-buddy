import Foundation

/// Minimal metadata needed to launch an installed app bundle.
public struct AppBundleInfo: Equatable, Sendable {
    /// Bundle identifier used by simulator and device launch commands.
    public let bundleIdentifier: String

    /// Executable name used for process-scoped log streaming.
    public let executableName: String?

    /// Platforms declared by `CFBundleSupportedPlatforms`.
    public let supportedPlatforms: [String]

    /// Creates app bundle metadata.
    public init(
        bundleIdentifier: String,
        executableName: String? = nil,
        supportedPlatforms: [String] = []
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.executableName = executableName
        self.supportedPlatforms = supportedPlatforms
    }
}
