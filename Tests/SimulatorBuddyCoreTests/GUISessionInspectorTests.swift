import Foundation
import Testing
@testable import SimulatorBuddyCore

struct GUISessionInspectorTests {
    @Test
    func hasGUISession_usesCorrectCoreGraphicsKey() {
        #expect(
            GUISessionInspector.hasGUISession(
                sessionInfo: ["kCGSSessionOnConsoleKey": 1]
            )
        )
        #expect(
            GUISessionInspector.hasGUISession(
                sessionInfo: ["kCGSessionOnConsoleKey": 1]
            ) == false
        )
    }

    @Test
    func hasGUISession_acceptsNSNumberAndBool() {
        #expect(
            GUISessionInspector.hasGUISession(
                sessionInfo: ["kCGSSessionOnConsoleKey": NSNumber(value: 1)]
            )
        )
        #expect(
            GUISessionInspector.hasGUISession(
                sessionInfo: ["kCGSSessionOnConsoleKey": true]
            )
        )
        #expect(
            GUISessionInspector.hasGUISession(
                sessionInfo: ["kCGSSessionOnConsoleKey": NSNumber(value: 0)]
            ) == false
        )
    }
}
