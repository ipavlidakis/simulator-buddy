import Foundation

/// Top-level JSON payload emitted by `devicectl`.
struct DeviceControlPayload: Decodable {
    /// Result object containing decoded devices.
    let result: DeviceControlResult
}
