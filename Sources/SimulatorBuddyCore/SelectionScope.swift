import CryptoKit
import Foundation

public struct SelectionScope: Codable, Equatable, Sendable {
    public let key: String
    public let label: String
    public let isExplicit: Bool

    public init(key: String, label: String, isExplicit: Bool) {
        self.key = key
        self.label = label
        self.isExplicit = isExplicit
    }

    public static func automatic(workingDirectory: URL) -> SelectionScope {
        let standardized = workingDirectory.standardizedFileURL
        return SelectionScope(
            key: standardized.path,
            label: standardized.lastPathComponent.isEmpty ? standardized.path : standardized.lastPathComponent,
            isExplicit: false
        )
    }

    public static func explicit(_ key: String) -> SelectionScope {
        SelectionScope(key: key, label: key, isExplicit: true)
    }

    var fileNameHash: String {
        let digest = SHA256.hash(data: Data(key.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
