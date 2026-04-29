import Foundation

/// Xcode root that owns a scheme.
public enum XcodeSchemeRoot: Sendable, Equatable {
    /// `.xcodeproj` file path.
    case project(URL)

    /// `.xcworkspace` file path.
    case workspace(URL)
}
