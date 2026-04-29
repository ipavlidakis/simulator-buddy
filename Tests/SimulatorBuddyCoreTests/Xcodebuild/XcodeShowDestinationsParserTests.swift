import Foundation
import Testing
@testable import SimulatorBuddyCore

/// Tests for parsing xcodebuild `-showdestinations` output.
struct XcodeShowDestinationsParserTests {
    /// Verifies Mac variants keep distinct xcodebuild destination specifiers.
    @Test
    func parseMacOSRunDestinations_extractsVariantIdAndSpecifier() {
        let stdout = """
        Available destinations for scheme:
        \\t\\t{ platform:macOS, arch:arm64, variant:Designed for [iPad,iPhone], id:00006000-aaa, name:My Mac }
        \\t\\t{ platform:macOS, arch:arm64, variant:Mac Catalyst, id:00006000-aaa, name:My Mac }
        """

        let records = XcodeShowDestinationsParser().parseMacOSRunDestinations(from: stdout)

        #expect(records.count == 2)
        #expect(records[0].udid == "00006000-aaa")
        #expect(
            records[0].xcodeDestinationSpecifier
                == "platform=macOS,arch=arm64,variant=Designed for iPad,id=00006000-aaa"
        )
        #expect(records[0].macOSVariant == "Designed for [iPad,iPhone]")
        #expect(records[1].macOSVariant == "Mac Catalyst")
        #expect(records[0].selectionIdentifier != records[1].selectionIdentifier)

        let ipadOnly = MacOSRecordsFilter.designedForIPad.filteredRecords(from: records)
        let catalystOnly = MacOSRecordsFilter.catalyst.filteredRecords(from: records)
        #expect(ipadOnly.map(\.udid) == ["00006000-aaa"])
        #expect(catalystOnly.map(\.udid) == ["00006000-aaa"])
    }

    /// Verifies available iOS, device, and Mac rows are parsed while ineligible rows are skipped.
    @Test
    func parseRunDestinations_extractsAvailableIOSAndMacRows() {
        let stdout = """
        Available destinations for the "App" scheme:
            { platform:iOS Simulator, arch:arm64, id:SIM-1, OS:26.5, name:iPhone Air }
            { platform:iOS, arch:arm64, id:DEVICE-1, name:iPhone Blue }
            { platform:macOS, arch:arm64, variant:Mac Catalyst, id:MAC-1, name:My Mac }
        Ineligible destinations for the "App" scheme:
            { platform:iOS Simulator, id:SIM-2, OS:26.5, name:iPhone Offline, error:Device unavailable }
            { platform:iOS, id:dvtdevice-DVTiPhonePlaceholder-iphoneos:placeholder, name:Any iOS Device }
        """

        let records = XcodeShowDestinationsParser().parseRunDestinations(from: stdout)

        #expect(records.map(\.kind) == [.simulator, .device, .macOS])
        #expect(records.map(\.udid) == ["SIM-1", "DEVICE-1", "MAC-1"])
        #expect(records[0].runtime == "iOS 26.5")
        #expect(records[0].xcodeDestinationSpecifier == "platform=iOS Simulator,id=SIM-1")
        #expect(records[1].xcodeDestinationSpecifier == "platform=iOS,id=DEVICE-1")
        #expect(
            records[2].xcodeDestinationSpecifier == "platform=macOS,arch=arm64,variant=Mac Catalyst,id=MAC-1"
        )
    }
}
