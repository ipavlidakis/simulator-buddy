import CryptoKit
import Foundation

/// Names the project-specific bucket used for last-selected destination history.
public struct SelectionScope: Codable, Equatable, Sendable {
    /// Stable key used for hashing the scope file name.
    public let key: String

    /// Human-readable label shown in picker output and debug JSON.
    public let label: String

    /// Indicates whether the scope was supplied by the caller instead of inferred.
    public let isExplicit: Bool

    /// Creates a scope from a stable key, display label, and explicitness flag.
    public init(key: String, label: String, isExplicit: Bool) {
        self.key = key
        self.label = label
        self.isExplicit = isExplicit
    }

    /// Creates an inferred scope from the standardized working directory path.
    public init(workingDirectory: URL) {
        let standardized = workingDirectory.standardizedFileURL
        key = standardized.path
        label = standardized.lastPathComponent.isEmpty ? standardized.path : standardized.lastPathComponent
        isExplicit = false
    }

    /// Creates a caller-defined scope with the same value for key and label.
    public init(explicit key: String) {
        self.key = key
        label = key
        isExplicit = true
    }

    /// SHA-256 file-system-safe name used for this scope's history file.
    var fileNameHash: String {
        let digest = SHA256.hash(data: Data(key.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
