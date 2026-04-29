import Foundation

/// Decoded simulator row from `simctl list devices --json`.
struct SimctlDevice: Decodable {
    /// Simulator UDID.
    let udid: String

    /// Availability flag supplied by CoreSimulator.
    let isAvailable: Bool?

    /// Simulator display name.
    let name: String

    /// Raw simulator state.
    let state: String

    /// Last boot timestamp when CoreSimulator provides it.
    let lastBootedAt: Date?
}
