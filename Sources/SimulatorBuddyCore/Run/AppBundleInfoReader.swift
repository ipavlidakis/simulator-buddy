import Foundation

/// Reads launch metadata from a local `.app` bundle.
public final class AppBundleInfoReader: Sendable {
    /// Creates an app bundle metadata reader.
    public init() {}

    /// Reads `CFBundleIdentifier` from the app bundle's `Info.plist`.
    public func read(at appURL: URL) throws -> AppBundleInfo {
        let plistURL = appURL.appendingPathComponent("Info.plist")
        let data = try Data(contentsOf: plistURL)
        guard let plist = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) as? [String: Any],
              let bundleIdentifier = plist["CFBundleIdentifier"] as? String,
              bundleIdentifier.isEmpty == false else {
            throw SimulatorBuddyError.usage("Missing CFBundleIdentifier in \(plistURL.path).")
        }
        let supportedPlatforms = plist["CFBundleSupportedPlatforms"] as? [String] ?? []
        return AppBundleInfo(
            bundleIdentifier: bundleIdentifier,
            supportedPlatforms: supportedPlatforms
        )
    }
}
