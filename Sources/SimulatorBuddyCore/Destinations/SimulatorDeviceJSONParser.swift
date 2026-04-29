import Foundation

/// Parses Apple command output into normalized destination records.
public struct SimulatorDeviceJSONParser: Sendable {
    /// Creates a stateless destination parser.
    public init() {}

    /// Parses `simctl list devices --json` data into supported simulator records.
    public func parseSimulators(from data: Data) throws -> [DestinationRecord] {
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

    /// Parses `devicectl list devices --json-output` data into supported physical devices.
    public func parseDevices(from data: Data) throws -> [DestinationRecord] {
        let decoder = JSONDecoder()
        let payload = try decoder.decode(DeviceControlPayload.self, from: data)

        return payload.result.devices.compactMap { device -> DestinationRecord? in
            guard isSupportedDevice(device) else {
                return nil
            }

            return DestinationRecord(
                kind: .device,
                udid: device.hardwareProperties.udid,
                name: sanitizedDeviceName(device.deviceProperties.name),
                runtime: runtimeLabel(
                    platform: device.hardwareProperties.platform,
                    version: device.deviceProperties.osVersionNumber
                ),
                state: normalizedDeviceState(for: device),
                stateDescription: normalizedDeviceStateDescription(for: device),
                sourceIdentifier: device.identifier
            )
        }
        .sorted(by: sortRecords)
    }

    /// Parses `xctrace list devices` output into local Mac destinations.
    public func parseMacs(from output: String, osVersion: String) -> [DestinationRecord] {
        var isInDevicesSection = false

        return output
            .components(separatedBy: .newlines)
            .compactMap { rawLine -> DestinationRecord? in
                let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                guard line.isEmpty == false else {
                    return nil
                }

                if line.hasPrefix("== ") {
                    isInDevicesSection = line == "== Devices =="
                    return nil
                }

                guard isInDevicesSection,
                      let parsed = parseXctraceDeviceLine(line),
                      isSupportedMacName(parsed.name) else {
                    return nil
                }

                return DestinationRecord(
                    kind: .macOS,
                    udid: parsed.udid,
                    name: parsed.name,
                    runtime: macOSRuntimeLabel(osVersion: osVersion, fallbackVersion: parsed.version),
                    state: .available,
                    stateDescription: "Available"
                )
            }
            .sorted(by: sortRecords)
    }

    /// Returns true for available iPhone and iPad simulator rows.
    private func isSupportedSimulator(_ device: SimctlDevice) -> Bool {
        guard device.isAvailable ?? true else {
            return false
        }
        return device.name.hasPrefix("iPhone") || device.name.hasPrefix("iPad")
    }

    /// Returns true for physical iPhone and iPad devices.
    private func isSupportedDevice(_ device: DeviceControlDevice) -> Bool {
        switch device.hardwareProperties.deviceType {
        case "iPhone", "iPad":
            return true
        default:
            return false
        }
    }

    /// Returns true for xctrace rows representing the local Mac.
    private func isSupportedMacName(_ name: String) -> Bool {
        name.localizedCaseInsensitiveContains("mac")
    }

    /// Normalizes CoreSimulator state text.
    private func simulatorState(from rawValue: String) -> DestinationState {
        switch rawValue.lowercased() {
        case "booted":
            return .booted
        case "shutdown":
            return .shutdown
        default:
            return .unknown
        }
    }

    /// Normalizes CoreDevice connection metadata into picker state.
    private func normalizedDeviceState(for device: DeviceControlDevice) -> DestinationState {
        let tunnelState = device.connectionProperties.tunnelState?.lowercased()
        let pairingState = device.connectionProperties.pairingState?.lowercased()
        let transport = device.connectionProperties.transportType?.lowercased()
        let bootState = device.deviceProperties.bootState?.lowercased()

        if tunnelState == "connected" || (bootState == "booted" && transport == "wired") {
            return .connected
        }

        if pairingState == "paired" {
            return transport == nil ? .unavailable : .available
        }

        if tunnelState == "disconnected" {
            return .disconnected
        }

        return .unknown
    }

    /// Builds user-visible state text for a physical device.
    private func normalizedDeviceStateDescription(for device: DeviceControlDevice) -> String {
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
            return device.connectionProperties.tunnelState?.capitalized ?? "Unknown"
        }
    }

    /// Removes private-use Apple glyph prefixes from device names.
    private func sanitizedDeviceName(_ name: String) -> String {
        name.trimmingCharacters(in: CharacterSet(charactersIn: "\u{F8FF} "))
    }

    /// Converts a CoreSimulator runtime key into a compact label.
    private func runtimeLabel(from runtimeKey: String) -> String {
        guard let token = runtimeKey.split(separator: ".").last else {
            return runtimeKey
        }

        return token.replacingOccurrences(of: "iOS-", with: "iOS ")
            .replacingOccurrences(of: "-", with: ".")
    }

    /// Builds a physical device runtime label from platform and version fields.
    private func runtimeLabel(platform: String, version: String?) -> String? {
        guard let version, version.isEmpty == false else {
            return nil
        }
        return "\(platform) \(version)"
    }

    /// Builds a Mac runtime label using host version with xctrace fallback.
    private func macOSRuntimeLabel(osVersion: String, fallbackVersion: String?) -> String {
        let version = osVersion.isEmpty ? fallbackVersion : osVersion
        guard let version, version.isEmpty == false else {
            return "macOS"
        }
        return "macOS \(version)"
    }

    /// Parses one xctrace device line into display name, optional version, and identifier.
    private func parseXctraceDeviceLine(_ line: String) -> (name: String, version: String?, udid: String)? {
        guard line.last == ")",
              let udidStart = line.lastIndex(of: "(") else {
            return nil
        }

        let udidStartIndex = line.index(after: udidStart)
        let udidEndIndex = line.index(before: line.endIndex)
        let udid = String(line[udidStartIndex..<udidEndIndex])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        var prefix = String(line[..<udidStart])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard udid.isEmpty == false, prefix.isEmpty == false else {
            return nil
        }

        var version: String?
        if prefix.last == ")",
           let versionStart = prefix.lastIndex(of: "(") {
            let versionStartIndex = prefix.index(after: versionStart)
            let versionEndIndex = prefix.index(before: prefix.endIndex)
            version = String(prefix[versionStartIndex..<versionEndIndex])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            prefix = String(prefix[..<versionStart])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return (name: prefix, version: version, udid: udid)
    }

    /// Orders records using their normalized sort keys.
    private func sortRecords(_ lhs: DestinationRecord, _ rhs: DestinationRecord) -> Bool {
        lhs.sortKey < rhs.sortKey
    }
}
