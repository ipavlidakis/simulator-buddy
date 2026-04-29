import Foundation

/// Resolves all on-disk locations used by simulator-buddy.
public struct AppPaths: Sendable {
    /// Reverse-DNS identifier used as default Application Support folder name.
    public let bundleIdentifier: String

    /// Root directory containing all simulator-buddy state.
    public let rootDirectory: URL

    /// Directory containing global and scoped history files.
    public let historyDirectory: URL

    /// Directory containing per-scope history files.
    public let scopesDirectory: URL

    /// Directory containing cached destination snapshots.
    public let cacheDirectory: URL

    /// Directory containing stable Mac wrapper bundles for iPhoneOS-on-Mac runs.
    public let macRunDirectory: URL

    /// JSON file storing the global last-used destination history.
    public let globalHistoryFile: URL

    /// JSON file storing the cached simulator/device/Mac destinations.
    public let destinationCacheFile: URL

    /// Creates path values from an explicit root or the user's Application Support folder.
    public init(
        rootDirectory: URL? = nil,
        fileManager: FileManager = .default,
        bundleIdentifier: String = "com.ipavlidakis.simulator-buddy"
    ) {
        self.bundleIdentifier = bundleIdentifier
        let resolvedRoot: URL
        if let rootDirectory {
            resolvedRoot = rootDirectory
        } else {
            let applicationSupport = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? fileManager.homeDirectoryForCurrentUser
            resolvedRoot = applicationSupport
                .appendingPathComponent(bundleIdentifier, isDirectory: true)
        }

        self.rootDirectory = resolvedRoot
        historyDirectory = resolvedRoot.appendingPathComponent("history", isDirectory: true)
        scopesDirectory = historyDirectory.appendingPathComponent("scopes", isDirectory: true)
        cacheDirectory = resolvedRoot.appendingPathComponent("cache", isDirectory: true)
        if rootDirectory == nil {
            macRunDirectory = fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications", isDirectory: true)
                .appendingPathComponent("simulator-buddy", isDirectory: true)
        } else {
            macRunDirectory = resolvedRoot.appendingPathComponent("mac-run", isDirectory: true)
        }
        globalHistoryFile = historyDirectory.appendingPathComponent("global.json")
        destinationCacheFile = cacheDirectory.appendingPathComponent("destinations.json")
    }

    /// Returns the scoped history file URL for a project or explicit selection scope.
    public func historyFile(for scope: SelectionScope) -> URL {
        scopesDirectory.appendingPathComponent("\(scope.fileNameHash).json")
    }
}
