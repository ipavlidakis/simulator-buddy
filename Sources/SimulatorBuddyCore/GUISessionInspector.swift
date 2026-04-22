import Foundation

public enum GUISessionInspector {
    public static func hasGUISession(sessionInfo: [AnyHashable: Any]) -> Bool {
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
