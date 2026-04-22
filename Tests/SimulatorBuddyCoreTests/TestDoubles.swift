import Foundation
@testable import SimulatorBuddyCore

actor InMemoryCacheStore: DestinationCacheStoring {
    var snapshot: DestinationCacheSnapshot

    init(snapshot: DestinationCacheSnapshot = DestinationCacheSnapshot()) {
        self.snapshot = snapshot
    }

    func load() async throws -> DestinationCacheSnapshot {
        snapshot
    }

    func update(
        kind: DestinationKind,
        records: [DestinationRecord],
        fetchedAt: Date
    ) async throws -> DestinationCacheSnapshot {
        snapshot.update(kind: kind, records: records, fetchedAt: fetchedAt)
        return snapshot
    }
}

actor StubHistoryProvider: HistoryProviding {
    var simulatorEntry: HistoryEntry?
    var deviceEntry: HistoryEntry?
    var allEntry: HistoryEntry?

    init(
        simulatorEntry: HistoryEntry? = nil,
        deviceEntry: HistoryEntry? = nil,
        allEntry: HistoryEntry? = nil
    ) {
        self.simulatorEntry = simulatorEntry
        self.deviceEntry = deviceEntry
        self.allEntry = allEntry
    }

    func resolveLast(type: DestinationQueryType, scope: SelectionScope?) async throws -> HistoryEntry? {
        switch type {
        case .simulator:
            return simulatorEntry
        case .device:
            return deviceEntry
        case .all:
            return allEntry ?? simulatorEntry ?? deviceEntry
        }
    }
}

actor StaticDestinationFetcher: DestinationFetching {
    let simulators: [DestinationRecord]
    let devices: [DestinationRecord]

    init(simulators: [DestinationRecord], devices: [DestinationRecord]) {
        self.simulators = simulators
        self.devices = devices
    }

    func fetchSimulators() async throws -> [DestinationRecord] {
        simulators
    }

    func fetchDevices() async throws -> [DestinationRecord] {
        devices
    }
}

actor ContinuationDestinationFetcher: DestinationFetching {
    private var simulatorContinuation: CheckedContinuation<[DestinationRecord], Error>?
    private let devices: [DestinationRecord]

    init(devices: [DestinationRecord] = []) {
        self.devices = devices
    }

    func fetchSimulators() async throws -> [DestinationRecord] {
        try await withCheckedThrowingContinuation { continuation in
            simulatorContinuation = continuation
        }
    }

    func fetchDevices() async throws -> [DestinationRecord] {
        devices
    }

    func resumeSimulators(with result: Result<[DestinationRecord], Error>) {
        simulatorContinuation?.resume(with: result)
        simulatorContinuation = nil
    }
}

final class StubPickerPresenter: PickerPresenting, @unchecked Sendable {
    private let result: Result<DestinationRecord, Error>

    init(result: Result<DestinationRecord, Error>) {
        self.result = result
    }

    func present(queryType: DestinationQueryType, scope: SelectionScope?) async throws -> DestinationRecord {
        try result.get()
    }
}

final class OutputRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var values: [String] = []

    func write(_ value: String) {
        lock.lock()
        values.append(value)
        lock.unlock()
    }

    func snapshot() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return values
    }
}

func eventually(
    timeoutNanoseconds: UInt64 = 1_000_000_000,
    intervalNanoseconds: UInt64 = 25_000_000,
    operation: @escaping @Sendable () async -> Bool
) async -> Bool {
    let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds

    while DispatchTime.now().uptimeNanoseconds < deadline {
        if await operation() {
            return true
        }

        try? await Task.sleep(nanoseconds: intervalNanoseconds)
    }

    return await operation()
}
