import Foundation

/// Decoded hardware metadata for a physical device.
struct DeviceHardwareProperties: Decodable {
    /// Device model class reported by CoreDevice.
    let deviceType: String

    /// Platform identifier, such as iOS.
    let platform: String

    /// Stable device UDID.
    let udid: String
}
