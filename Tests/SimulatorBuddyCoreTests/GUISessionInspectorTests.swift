import Foundation
import Testing
@testable import SimulatorBuddyCore

/// Tests for CoreGraphics GUI session metadata interpretation.
struct GUISessionInspectorTests {
    /// Verifies the inspector reads the exact CoreGraphics console-session key.
    @Test
    func hasGUISession_usesCorrectCoreGraphicsKey() {
        #expect(
            GUISessionInspector().hasGUISession(
                sessionInfo: ["kCGSSessionOnConsoleKey": 1]
            )
        )
        #expect(
            GUISessionInspector().hasGUISession(
                sessionInfo: ["kCGSessionOnConsoleKey": 1]
            ) == false
        )
    }

    /// Verifies common CoreGraphics value representations are accepted.
    @Test
    func hasGUISession_acceptsNSNumberAndBool() {
        #expect(
            GUISessionInspector().hasGUISession(
                sessionInfo: ["kCGSSessionOnConsoleKey": NSNumber(value: 1)]
            )
        )
        #expect(
            GUISessionInspector().hasGUISession(
                sessionInfo: ["kCGSSessionOnConsoleKey": true]
            )
        )
        #expect(
            GUISessionInspector().hasGUISession(
                sessionInfo: ["kCGSSessionOnConsoleKey": NSNumber(value: 0)]
            ) == false
        )
    }
}
