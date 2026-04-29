import Foundation

/// Minimal metadata needed to launch an installed app bundle.
public struct AppBundleInfo: Equatable, Sendable {
    /// Bundle identifier used by `simctl launch`.
    public let bundleIdentifier: String

    /// Platforms declared by `CFBundleSupportedPlatforms`.
    public let supportedPlatforms: [String]

    /// Creates app bundle metadata.
    public init(bundleIdentifier: String, supportedPlatforms: [String] = []) {
        self.bundleIdentifier = bundleIdentifier
        self.supportedPlatforms = supportedPlatforms
    }
}
