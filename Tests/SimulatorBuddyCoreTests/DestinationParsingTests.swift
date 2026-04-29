import Foundation
import Testing
@testable import SimulatorBuddyCore

struct DestinationParsingTests {
    @Test
    func parseSimulators_filtersUnsupportedDevicesAndBuildsRuntimeLabels() throws {
        let payload = """
        {
          "devices": {
            "com.apple.CoreSimulator.SimRuntime.iOS-26-5": [
              {
                "udid": "SIM-BOOTED",
                "isAvailable": true,
                "name": "iPhone Air",
                "state": "Booted",
                "lastBootedAt": "2026-04-22T10:54:32Z"
              },
              {
                "udid": "SIM-TV",
                "isAvailable": true,
                "name": "Apple TV",
                "state": "Shutdown"
              }
            ],
            "com.apple.CoreSimulator.SimRuntime.iOS-26-3": [
              {
                "udid": "SIM-IPAD",
                "isAvailable": true,
                "name": "iPad (A16)",
                "state": "Shutdown"
              }
            ]
          }
        }
        """

        let records = try SimulatorDeviceJSONParser.parseSimulators(from: Data(payload.utf8))

        #expect(records.map(\.udid) == ["SIM-BOOTED", "SIM-IPAD"])
        #expect(records[0].state == .booted)
        #expect(records[0].runtime == "iOS 26.5")
        #expect(records[1].runtime == "iOS 26.3")
    }

    @Test
    func parseDevices_extractsPhysicalUDIDsAndNormalizesState() throws {
        let payload = """
        {
          "result": {
            "devices": [
              {
                "identifier": "CORE-DEVICE-1",
                "connectionProperties": {
                  "pairingState": "paired",
                  "transportType": "wired",
                  "tunnelState": "connected"
                },
                "deviceProperties": {
                  "name": "\\uf8ff iPhone Blue",
                  "osVersionNumber": "26.4",
                  "bootState": "booted"
                },
                "hardwareProperties": {
                  "deviceType": "iPhone",
                  "platform": "iOS",
                  "udid": "DEVICE-UDID-1"
                }
              },
              {
                "identifier": "CORE-DEVICE-2",
                "connectionProperties": {
                  "pairingState": "paired",
                  "transportType": "localNetwork",
                  "tunnelState": "disconnected"
                },
                "deviceProperties": {
                  "name": "\\uf8ff iPad Green",
                  "osVersionNumber": "26.3"
                },
                "hardwareProperties": {
                  "deviceType": "iPad",
                  "platform": "iOS",
                  "udid": "DEVICE-UDID-2"
                }
              },
              {
                "identifier": "CORE-DEVICE-3",
                "connectionProperties": {
                  "pairingState": "paired"
                },
                "deviceProperties": {
                  "name": "\\uf8ff iPhone Offline",
                  "osVersionNumber": "26.5"
                },
                "hardwareProperties": {
                  "deviceType": "iPhone",
                  "platform": "iOS",
                  "udid": "DEVICE-UDID-3"
                }
              },
              {
                "identifier": "CORE-WATCH",
                "connectionProperties": {
                  "pairingState": "paired"
                },
                "deviceProperties": {
                  "name": "\\uf8ff Watch",
                  "osVersionNumber": "26.3"
                },
                "hardwareProperties": {
                  "deviceType": "Watch",
                  "platform": "watchOS",
                  "udid": "WATCH-UDID"
                }
              }
            ]
          }
        }
        """

        let records = try SimulatorDeviceJSONParser.parseDevices(from: Data(payload.utf8))

        #expect(records.map(\.udid) == ["DEVICE-UDID-1", "DEVICE-UDID-2", "DEVICE-UDID-3"])
        #expect(records[0].state == .connected)
        #expect(records[0].name == "iPhone Blue")
        #expect(records[1].state == .available)
        #expect(records[2].state == .unavailable)
        #expect(records[0].runtime == "iOS 26.4")
    }

    @Test
    func parseMacs_extractsAvailableMacsFromXctraceDevicesSection() throws {
        let output = """
        == Devices ==
        MacBook Pro (MAC-UDID-1)
        iPhone Blue (26.4) (DEVICE-UDID-1)

        == Devices Offline ==
        Mac mini (MAC-UDID-OFFLINE)

        == Simulators ==
        iPhone Air Simulator (26.5) (SIM-UDID-1)
        """

        let records = SimulatorDeviceJSONParser.parseMacs(
            from: output,
            osVersion: "15.5"
        )

        #expect(records == [
            DestinationRecord(
                kind: .macOS,
                udid: "MAC-UDID-1",
                name: "MacBook Pro",
                runtime: "macOS 15.5",
                state: .available,
                stateDescription: "Available"
            ),
        ])
    }

    @Test
    func parseMacOSRunDestinations_extractsVariantIdAndSpecifier() {
        let stdout = """
        Available destinations for scheme:
        \\t\\t{ platform:macOS, arch:arm64, variant:Designed for [iPad,iPhone], id:00006000-aaa, name:My Mac }
        \\t\\t{ platform:macOS, arch:arm64, variant:Mac Catalyst, id:00006000-aaa, name:My Mac }
        """

        let records = XcodeShowDestinationsParser.parseMacOSRunDestinations(from: stdout)

        #expect(records.count == 2)
        #expect(records[0].udid == "00006000-aaa")
        #expect(
            records[0].xcodeDestinationSpecifier
                == "platform=macOS,arch=arm64,variant=Designed for [iPad,iPhone],id=00006000-aaa"
        )
        #expect(records[0].macOSVariant == "Designed for [iPad,iPhone]")
        #expect(records[1].macOSVariant == "Mac Catalyst")
        #expect(records[0].selectionIdentifier != records[1].selectionIdentifier)

        let ipadOnly = MacOSRecordsFilter.designedForIPad.filteredRecords(from: records)
        let catalystOnly = MacOSRecordsFilter.catalyst.filteredRecords(from: records)
        #expect(ipadOnly.map(\.udid) == ["00006000-aaa"])
        #expect(catalystOnly.map(\.udid) == ["00006000-aaa"])
    }
}
