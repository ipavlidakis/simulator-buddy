import Foundation

/// Identifies an Xcode project or workspace plus scheme for resolving run destinations.
public struct XcodeSchemeContext: Sendable, Equatable {
    public enum Root: Sendable, Equatable {
        case project(URL)
        case workspace(URL)
    }

    public let root: Root
    public let scheme: String

    public init(root: Root, scheme: String) {
        self.root = root
        self.scheme = scheme
    }
}
