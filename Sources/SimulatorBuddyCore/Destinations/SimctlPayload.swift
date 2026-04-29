import Foundation

/// Top-level `simctl` JSON payload grouped by runtime identifier.
struct SimctlPayload: Decodable {
    /// Devices keyed by CoreSimulator runtime identifier.
    let devices: [String: [SimctlDevice]]
}
