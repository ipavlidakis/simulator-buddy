import Foundation
@testable import SimulatorBuddyCore

/// Destination fetcher test double that returns fixed record arrays.
actor StaticDestinationFetcher: DestinationFetching {
    /// Simulator records returned by the fetcher.
    let simulators: [DestinationRecord]

    /// Physical device records returned by the fetcher.
    let devices: [DestinationRecord]

    /// Mac records returned by the fetcher.
    let macs: [DestinationRecord]

    /// Creates a fetcher with fixed destination records.
    init(simulators: [DestinationRecord], devices: [DestinationRecord], macs: [DestinationRecord] = []) {
        self.simulators = simulators
        self.devices = devices
        self.macs = macs
    }

    /// Returns fixed simulator records.
    func fetchSimulators() async throws -> [DestinationRecord] {
        simulators
    }

    /// Returns fixed physical device records.
    func fetchDevices() async throws -> [DestinationRecord] {
        devices
    }

    /// Returns fixed Mac records.
    func fetchMacs() async throws -> [DestinationRecord] {
        macs
    }

    /// Returns fixed Mac records for Xcode-backed destination requests.
    func fetchMacRunDestinationsFromXcode(context: XcodeSchemeContext) async throws -> [DestinationRecord] {
        macs
    }
}
