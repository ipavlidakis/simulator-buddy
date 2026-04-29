import Foundation

/// Decoded display and OS properties for a physical device.
struct DeviceProperties: Decodable {
    /// User-visible device name.
    let name: String

    /// OS version string when available.
    let osVersionNumber: String?

    /// Raw boot state reported by CoreDevice.
    let bootState: String?
}
