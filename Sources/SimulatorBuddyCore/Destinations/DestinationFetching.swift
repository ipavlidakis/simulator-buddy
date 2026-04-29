import Foundation

/// Loads destinations from system tools and Xcode.
public protocol DestinationFetching: Sendable {
    /// Fetches available iPhone and iPad simulators.
    func fetchSimulators() async throws -> [DestinationRecord]

    /// Fetches connected or known physical iPhone and iPad devices.
    func fetchDevices() async throws -> [DestinationRecord]

    /// Fetches local Mac destinations from system tooling.
    func fetchMacs() async throws -> [DestinationRecord]

    /// Fetches Xcode run destinations for Mac variants for a scheme.
    func fetchMacRunDestinationsFromXcode(context: XcodeSchemeContext) async throws -> [DestinationRecord]
}
