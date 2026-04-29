import CoreGraphics
import SimulatorBuddyCore

/// Checks whether the current process can present AppKit UI.
struct GUISessionAvailability {
    /// Returns true when CoreGraphics reports an on-console GUI session.
    func isAvailable() -> Bool {
        guard let dictionary = CGSessionCopyCurrentDictionary() as? [AnyHashable: Any] else {
            return false
        }

        return GUISessionInspector().hasGUISession(sessionInfo: dictionary)
    }
}
