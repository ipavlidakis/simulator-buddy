import Foundation
import Testing
@testable import SimulatorBuddyCore

/// Tests on-disk path resolution.
struct AppPathsTests {
    /// Verifies production Mac wrappers live where LaunchServices accepts them.
    @Test
    func defaultPaths_storeMacRunBundlesInUserApplications() {
        let paths = AppPaths()

        #expect(paths.macRunDirectory.path.hasSuffix("/Applications/simulator-buddy"))
    }

    /// Verifies explicit roots keep all paths local to the test root.
    @Test
    func explicitRoot_keepsMacRunBundlesUnderRoot() {
        let rootDirectory = temporaryDirectory()
        let paths = AppPaths(rootDirectory: rootDirectory)

        #expect(paths.macRunDirectory == rootDirectory.appendingPathComponent("mac-run", isDirectory: true))
    }
}
