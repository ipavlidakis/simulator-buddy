import Foundation

/// Checks whether CoreGraphics session metadata describes an interactive GUI session.
public struct GUISessionInspector: Sendable {
    /// Creates a stateless GUI session inspector.
    public init() {}

    /// Returns true when the session is currently attached to the console.
    public func hasGUISession(sessionInfo: [AnyHashable: Any]) -> Bool {
        let value = sessionInfo["kCGSSessionOnConsoleKey"]

        switch value {
        case let number as NSNumber:
            return number.intValue == 1
        case let value as Int:
            return value == 1
        case let value as Bool:
            return value
        default:
            return false
        }
    }
}
