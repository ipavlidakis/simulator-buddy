import Foundation

/// `devicectl` result section containing physical devices.
struct DeviceControlResult: Decodable {
    /// Physical devices reported by CoreDevice.
    let devices: [DeviceControlDevice]
}
