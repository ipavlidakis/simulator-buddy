import Foundation

/// Creates minimal `.app` bundles for command-handler tests.
struct AppBundleFixtureFactory {
    /// File manager used for bundle directories and plist files.
    private let fileManager: FileManager

    /// Creates a fixture factory.
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Creates an app bundle with the requested identifier and supported platforms.
    func makeAppBundle(
        at appURL: URL,
        bundleIdentifier: String,
        supportedPlatforms: [String] = []
    ) throws {
        try fileManager.createDirectory(at: appURL, withIntermediateDirectories: true)
        let plistURL = appURL.appendingPathComponent("Info.plist")
        var plist: [String: Any] = ["CFBundleIdentifier": bundleIdentifier]
        if supportedPlatforms.isEmpty == false {
            plist["CFBundleSupportedPlatforms"] = supportedPlatforms
        }
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: plistURL)
    }
}
