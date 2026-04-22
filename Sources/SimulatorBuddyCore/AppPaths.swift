import Foundation

public struct AppPaths: Sendable {
    public static let bundleIdentifier = "com.ipavlidakis.simulator-buddy"

    public let rootDirectory: URL
    public let historyDirectory: URL
    public let scopesDirectory: URL
    public let cacheDirectory: URL
    public let globalHistoryFile: URL
    public let destinationCacheFile: URL

    public init(rootDirectory: URL? = nil, fileManager: FileManager = .default) {
        let resolvedRoot: URL
        if let rootDirectory {
            resolvedRoot = rootDirectory
        } else {
            let applicationSupport = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? fileManager.homeDirectoryForCurrentUser
            resolvedRoot = applicationSupport
                .appendingPathComponent(Self.bundleIdentifier, isDirectory: true)
        }

        self.rootDirectory = resolvedRoot
        historyDirectory = resolvedRoot.appendingPathComponent("history", isDirectory: true)
        scopesDirectory = historyDirectory.appendingPathComponent("scopes", isDirectory: true)
        cacheDirectory = resolvedRoot.appendingPathComponent("cache", isDirectory: true)
        globalHistoryFile = historyDirectory.appendingPathComponent("global.json")
        destinationCacheFile = cacheDirectory.appendingPathComponent("destinations.json")
    }

    public func historyFile(for scope: SelectionScope) -> URL {
        scopesDirectory.appendingPathComponent("\(scope.fileNameHash).json")
    }
}
