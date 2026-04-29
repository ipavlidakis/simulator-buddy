import Foundation
import Testing
@testable import SimulatorBuddyCore

/// Tests for parsing app product metadata from `xcodebuild -showBuildSettings`.
struct XcodeBuildSettingsParserTests {
    /// Verifies parser returns the app product from build settings output.
    @Test
    func parse_returnsAppProduct() throws {
        let output = """
        Build settings for action build and target StreamVideo:
            FULL_PRODUCT_NAME = StreamVideo.framework
            PRODUCT_BUNDLE_IDENTIFIER = io.getstream.framework
            TARGET_BUILD_DIR = /tmp/Build/Products/Debug-iphoneos

        Build settings for action build and target DemoApp:
            FULL_PRODUCT_NAME = Demo.app
            PRODUCT_BUNDLE_IDENTIFIER = com.example.Demo
            TARGET_BUILD_DIR = /tmp/Build/Products/Debug-iphoneos
        """

        let product = try XcodeBuildSettingsParser().parseBuiltProduct(from: output)

        #expect(product.appURL.path == "/tmp/Build/Products/Debug-iphoneos/Demo.app")
        #expect(product.bundleIdentifier == "com.example.Demo")
    }
}
