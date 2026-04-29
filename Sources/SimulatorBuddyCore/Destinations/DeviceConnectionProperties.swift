import Foundation

/// Decoded CoreDevice connection metadata for a physical device.
struct DeviceConnectionProperties: Decodable {
    /// Pairing state reported by `devicectl`.
    let pairingState: String?

    /// Transport type, such as USB or network.
    let transportType: String?

    /// Tunnel state used by device attach workflows.
    let tunnelState: String?
}
