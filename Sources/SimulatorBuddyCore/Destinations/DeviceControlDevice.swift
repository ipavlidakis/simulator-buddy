import Foundation

/// Decoded physical device row from `devicectl list devices`.
struct DeviceControlDevice: Decodable {
    /// CoreDevice identifier.
    let identifier: String

    /// Connection and pairing metadata.
    let connectionProperties: DeviceConnectionProperties

    /// User-visible device properties.
    let deviceProperties: DeviceProperties

    /// Hardware identity and platform metadata.
    let hardwareProperties: DeviceHardwareProperties
}
