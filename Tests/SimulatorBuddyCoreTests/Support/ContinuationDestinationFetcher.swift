import Foundation
@testable import SimulatorBuddyCore

/// Destination fetcher test double that suspends simulator fetches until resumed.
actor ContinuationDestinationFetcher: DestinationFetching {
    /// Pending simulator continuation controlled by tests.
    private var simulatorContinuation: CheckedContinuation<[DestinationRecord], Error>?

    /// Device records returned immediately.
    private let devices: [DestinationRecord]

    /// Mac records returned immediately.
    private let macs: [DestinationRecord]

    /// Creates a fetcher with fixed devices and Macs.
    init(devices: [DestinationRecord] = [], macs: [DestinationRecord] = []) {
        self.devices = devices
        self.macs = macs
    }

    /// Suspends until `resumeSimulators(with:)` supplies a result.
    func fetchSimulators() async throws -> [DestinationRecord] {
        try await withCheckedThrowingContinuation { continuation in
            simulatorContinuation = continuation
        }
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

    /// Resumes the pending simulator fetch.
    func resumeSimulators(with result: Result<[DestinationRecord], Error>) {
        simulatorContinuation?.resume(with: result)
        simulatorContinuation = nil
    }
}
