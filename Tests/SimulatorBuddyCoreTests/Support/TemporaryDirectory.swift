import Foundation

/// Creates a unique temporary directory URL for a test.
func temporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
}
