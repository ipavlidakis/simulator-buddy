import Foundation

public protocol DestinationFetching: Sendable {
    func fetchSimulators() async throws -> [DestinationRecord]
    func fetchDevices() async throws -> [DestinationRecord]
}

public enum SimulatorDeviceJSONParser {
    public static func parseSimulators(from data: Data) throws -> [DestinationRecord] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(SimctlPayload.self, from: data)

        return payload.devices
            .flatMap { runtimeKey, devices in
                devices.compactMap { device -> DestinationRecord? in
                    guard isSupportedSimulator(device) else {
                        return nil
                    }

                    return DestinationRecord(
                        kind: .simulator,
                        udid: device.udid,
                        name: device.name,
                        runtime: runtimeLabel(from: runtimeKey),
                        state: simulatorState(from: device.state),
                        stateDescription: device.state,
                        lastBootedAt: device.lastBootedAt
                    )
                }
            }
            .sorted(by: sortRecords)
    }

    public static func parseDevices(from data: Data) throws -> [DestinationRecord] {
        let decoder = JSONDecoder()
        let payload = try decoder.decode(DeviceControlPayload.self, from: data)

        return payload.result.devices.compactMap { device -> DestinationRecord? in
            guard isSupportedDevice(device) else {
                return nil
            }

            let stateDescription = normalizedDeviceStateDescription(for: device)

            return DestinationRecord(
                kind: .device,
                udid: device.hardwareProperties.udid,
                name: sanitizedDeviceName(device.deviceProperties.name),
                runtime: runtimeLabel(
                    platform: device.hardwareProperties.platform,
                    version: device.deviceProperties.osVersionNumber
                ),
                state: normalizedDeviceState(for: device),
                stateDescription: stateDescription,
                sourceIdentifier: device.identifier
            )
        }
        .sorted(by: sortRecords)
    }

    private static func isSupportedSimulator(_ device: SimctlDevice) -> Bool {
        guard device.isAvailable ?? true else {
            return false
        }

        return device.name.hasPrefix("iPhone") || device.name.hasPrefix("iPad")
    }

    private static func isSupportedDevice(_ device: DeviceControlDevice) -> Bool {
        switch device.hardwareProperties.deviceType {
        case "iPhone", "iPad":
            return true
        default:
            return false
        }
    }

    private static func simulatorState(from rawValue: String) -> DestinationState {
        switch rawValue.lowercased() {
        case "booted":
            return .booted
        case "shutdown":
            return .shutdown
        default:
            return .unknown
        }
    }

    private static func normalizedDeviceState(for device: DeviceControlDevice) -> DestinationState {
        let tunnelState = device.connectionProperties.tunnelState?.lowercased()
        let pairingState = device.connectionProperties.pairingState?.lowercased()
        let transport = device.connectionProperties.transportType?.lowercased()
        let bootState = device.deviceProperties.bootState?.lowercased()

        if tunnelState == "connected" || (bootState == "booted" && transport == "wired") {
            return .connected
        }

        if pairingState == "paired" {
            if transport == nil {
                return .unavailable
            }

            if tunnelState == "disconnected" {
                return .available
            }

            return .available
        }

        if tunnelState == "disconnected" {
            return .disconnected
        }

        return .unknown
    }

    private static func normalizedDeviceStateDescription(for device: DeviceControlDevice) -> String {
        switch normalizedDeviceState(for: device) {
        case .connected:
            return "Connected"
        case .available:
            return "Available (paired)"
        case .unavailable:
            return "Unavailable"
        case .disconnected:
            return "Disconnected"
        case .booted:
            return "Booted"
        case .shutdown:
            return "Shutdown"
        case .unknown:
            if let tunnelState = device.connectionProperties.tunnelState {
                return tunnelState.capitalized
            }

            return "Unknown"
        }
    }

    private static func sanitizedDeviceName(_ name: String) -> String {
        name.trimmingCharacters(in: CharacterSet(charactersIn: "\u{F8FF} "))
    }

    private static func runtimeLabel(from runtimeKey: String) -> String {
        guard let token = runtimeKey.split(separator: ".").last else {
            return runtimeKey
        }

        let value = token.replacingOccurrences(of: "iOS-", with: "iOS ")
            .replacingOccurrences(of: "-", with: ".")
        return value
    }

    private static func runtimeLabel(platform: String, version: String?) -> String? {
        guard let version, version.isEmpty == false else {
            return nil
        }

        return "\(platform) \(version)"
    }

    private static func sortRecords(_ lhs: DestinationRecord, _ rhs: DestinationRecord) -> Bool {
        lhs.sortKey < rhs.sortKey
    }
}

public final class SystemDestinationFetcher: DestinationFetching, @unchecked Sendable {
    private let runner: any CommandRunning
    private let fileManager: FileManager
    private let temporaryDirectory: URL

    public init(
        runner: any CommandRunning,
        fileManager: FileManager = .default,
        temporaryDirectory: URL = FileManager.default.temporaryDirectory
    ) {
        self.runner = runner
        self.fileManager = fileManager
        self.temporaryDirectory = temporaryDirectory
    }

    public func fetchSimulators() async throws -> [DestinationRecord] {
        let outputURL = temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")

        defer {
            try? fileManager.removeItem(at: outputURL)
        }

        let result = try await runner.run(
            Command(
                executable: "xcrun",
                arguments: [
                    "simctl",
                    "list",
                    "devices",
                    "available",
                    "-j",
                    "--json-output",
                    outputURL.path,
                ]
            )
        )

        guard result.terminationStatus == 0 else {
            throw SimulatorBuddyError.commandFailed(
                result.stderr.isEmpty ? "simctl list failed." : result.stderr
            )
        }

        let data = try Data(contentsOf: outputURL)
        return try SimulatorDeviceJSONParser.parseSimulators(from: data)
    }

    public func fetchDevices() async throws -> [DestinationRecord] {
        let outputURL = temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")

        defer {
            try? fileManager.removeItem(at: outputURL)
        }

        let result = try await runner.run(
            Command(
                executable: "xcrun",
                arguments: [
                    "devicectl",
                    "list",
                    "devices",
                    "--json-output",
                    outputURL.path,
                ]
            )
        )

        guard result.terminationStatus == 0 else {
            throw SimulatorBuddyError.commandFailed(
                result.stderr.isEmpty ? "devicectl list devices failed." : result.stderr
            )
        }

        let data = try Data(contentsOf: outputURL)
        return try SimulatorDeviceJSONParser.parseDevices(from: data)
    }
}

private struct SimctlPayload: Decodable {
    let devices: [String: [SimctlDevice]]
}

private struct SimctlDevice: Decodable {
    let udid: String
    let isAvailable: Bool?
    let name: String
    let state: String
    let lastBootedAt: Date?
}

private struct DeviceControlPayload: Decodable {
    let result: DeviceControlResult
}

private struct DeviceControlResult: Decodable {
    let devices: [DeviceControlDevice]
}

private struct DeviceControlDevice: Decodable {
    let identifier: String
    let connectionProperties: DeviceConnectionProperties
    let deviceProperties: DeviceProperties
    let hardwareProperties: DeviceHardwareProperties
}

private struct DeviceConnectionProperties: Decodable {
    let pairingState: String?
    let transportType: String?
    let tunnelState: String?
}

private struct DeviceProperties: Decodable {
    let name: String
    let osVersionNumber: String?
    let bootState: String?
}

private struct DeviceHardwareProperties: Decodable {
    let deviceType: String
    let platform: String
    let udid: String
}
