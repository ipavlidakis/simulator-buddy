import Foundation

/// Identifies an Xcode project or workspace plus scheme for resolving run destinations.
public struct XcodeSchemeContext: Sendable, Equatable {
    /// Project or workspace containing the scheme.
    public let root: XcodeSchemeRoot

    /// Xcode scheme used for `xcodebuild -showdestinations`.
    public let scheme: String

    /// Creates a scheme context from the owning root and scheme name.
    public init(root: XcodeSchemeRoot, scheme: String) {
        self.root = root
        self.scheme = scheme
    }
}
