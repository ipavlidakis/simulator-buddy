import Foundation

/// Creates a macOS-launchable wrapper around an iPhoneOS app bundle.
final class MacAppBundleWrapperBuilder: @unchecked Sendable {
    /// File manager used for wrapper directory operations.
    private let fileManager: FileManager

    /// Directory containing stable wrapper bundles.
    private let wrapperDirectory: URL

    /// Creates a wrapper builder.
    init(
        fileManager: FileManager = .default,
        wrapperDirectory: URL
    ) {
        self.fileManager = fileManager
        self.wrapperDirectory = wrapperDirectory
    }

    /// Builds a wrapper bundle and returns the wrapper `.app` URL.
    func wrappedAppURL(for appURL: URL, appInfo: AppBundleInfo) throws -> URL {
        let wrapperURL = wrapperDirectory
            .appendingPathComponent("\(safeBundleName(appInfo.bundleIdentifier)).app", isDirectory: true)
        let wrapperDirectoryURL = wrapperURL.appendingPathComponent("Wrapper", isDirectory: true)
        let copiedAppURL = wrapperDirectoryURL.appendingPathComponent(appURL.lastPathComponent, isDirectory: true)
        let wrappedBundleURL = wrapperURL.appendingPathComponent("WrappedBundle")
        let bundleMetadataURL = wrapperDirectoryURL.appendingPathComponent("BundleMetadata.plist")

        try fileManager.createDirectory(at: wrapperURL, withIntermediateDirectories: true)
        try removeExistingItem(at: wrapperDirectoryURL)
        try removeExistingItem(at: wrappedBundleURL)
        try fileManager.createDirectory(at: wrapperDirectoryURL, withIntermediateDirectories: true)
        try fileManager.copyItem(at: appURL, to: copiedAppURL)
        try writeBundleMetadata(at: bundleMetadataURL)
        try fileManager.createSymbolicLink(
            atPath: wrappedBundleURL.path,
            withDestinationPath: "Wrapper/\(appURL.lastPathComponent)"
        )

        return wrapperURL
    }

    /// Removes a stale file or directory when present.
    private func removeExistingItem(at url: URL) throws {
        let exists = fileManager.fileExists(atPath: url.path)
        let isSymbolicLink = (try? fileManager.destinationOfSymbolicLink(atPath: url.path)) != nil
        guard exists || isSymbolicLink else {
            return
        }
        try fileManager.removeItem(at: url)
    }

    /// Writes metadata required by LaunchServices for iPhoneOS-on-Mac wrappers.
    private func writeBundleMetadata(at url: URL) throws {
        let data = try PropertyListSerialization.data(
            fromPropertyList: [:],
            format: .xml,
            options: 0
        )
        try data.write(to: url, options: .atomic)
    }

    /// Converts a bundle identifier into a stable filesystem name.
    private func safeBundleName(_ bundleIdentifier: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_"))
        return String(bundleIdentifier.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        })
    }
}
