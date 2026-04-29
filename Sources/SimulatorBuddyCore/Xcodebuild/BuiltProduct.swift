import Foundation

/// App product resolved from Xcode build settings.
struct BuiltProduct: Equatable, Sendable {
    /// Absolute URL to the built `.app` bundle.
    let appURL: URL

    /// Bundle identifier reported by Xcode for the built product.
    let bundleIdentifier: String

    /// Creates built product metadata.
    init(appURL: URL, bundleIdentifier: String) {
        self.appURL = appURL
        self.bundleIdentifier = bundleIdentifier
    }
}
