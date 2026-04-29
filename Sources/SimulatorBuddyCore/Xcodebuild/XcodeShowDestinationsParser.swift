import Foundation

/// Parses `xcodebuild -showdestinations` output.
public struct XcodeShowDestinationsParser: Sendable {
    /// Creates a stateless `xcodebuild -showdestinations` parser.
    public init() {}

    /// Parses available, concrete run destinations from `xcodebuild -showdestinations`.
    public func parseRunDestinations(from stdout: String) -> [DestinationRecord] {
        var isAvailableSection = false

        return stdout
            .split(separator: "\n", omittingEmptySubsequences: false)
            .compactMap { lineRaw -> DestinationRecord? in
                let line = String(lineRaw).trimmingCharacters(in: .whitespaces)
                if line.hasPrefix("Available destinations") {
                    isAvailableSection = true
                    return nil
                }
                if line.hasPrefix("Ineligible destinations") {
                    isAvailableSection = false
                    return nil
                }

                guard isAvailableSection,
                      line.contains("platform:"),
                      line.contains(" error:") == false,
                      let platform = extract(
                        afterMarker: "platform:",
                        beforeMarkers: [", arch:", ", variant:", ", id:", ", OS:", ", name:", "}"],
                        in: line
                      )?.trimmingCharacters(in: .whitespaces),
                      let id = extract(afterMarker: "id:", beforeMarkers: [", OS:", ", name:", "}"], in: line),
                      id.isEmpty == false,
                      id.localizedCaseInsensitiveContains("placeholder") == false
                else {
                    return nil
                }

                let name = extract(
                    afterMarker: "name:",
                    beforeMarkers: ["}"],
                    in: line
                )?.trimmingCharacters(in: .whitespaces) ?? id
                let arch = extract(
                    afterMarker: "arch:",
                    beforeMarkers: [", variant:", ", id:", ", OS:", ", name:"],
                    in: line
                )?.trimmingCharacters(in: .whitespaces)
                let variant = extract(
                    afterMarker: "variant:",
                    beforeMarkers: [", id:", ", OS:", ", name:"],
                    in: line
                )?.trimmingCharacters(in: .whitespaces)
                let os = extract(
                    afterMarker: "OS:",
                    beforeMarkers: [", name:", "}"],
                    in: line
                )?.trimmingCharacters(in: .whitespaces)

                switch platform {
                case "iOS Simulator":
                    return DestinationRecord(
                        kind: .simulator,
                        udid: id,
                        name: name,
                        runtime: os.map { "iOS \($0)" },
                        state: .available,
                        stateDescription: "Available",
                        xcodeDestinationSpecifier: "platform=iOS Simulator,id=\(id)"
                    )
                case "iOS":
                    return DestinationRecord(
                        kind: .device,
                        udid: id,
                        name: name,
                        runtime: os.map { "iOS \($0)" },
                        state: .available,
                        stateDescription: "Available",
                        xcodeDestinationSpecifier: "platform=iOS,id=\(id)"
                    )
                case "macOS":
                    var specifierParts = ["platform=macOS"]
                    if let arch, arch.isEmpty == false {
                        specifierParts.append("arch=\(arch)")
                    }
                    if let destinationVariant = xcodeDestinationVariant(from: variant) {
                        specifierParts.append("variant=\(destinationVariant)")
                    }
                    specifierParts.append("id=\(id)")
                    let specifier = specifierParts.joined(separator: ",")
                    let displayName = variant.map { "\(name) - \($0)" } ?? name

                    return DestinationRecord(
                        kind: .macOS,
                        udid: id,
                        name: displayName,
                        runtime: variant ?? "macOS",
                        state: .available,
                        stateDescription: "Available",
                        macOSVariant: variant,
                        xcodeDestinationSpecifier: specifier
                    )
                default:
                    return nil
                }
            }
    }

    /// One row per `platform:macOS` destination without an `error:` clause.
    public func parseMacOSRunDestinations(from stdout: String) -> [DestinationRecord] {
        parseRunDestinations(from: stdout).filter { $0.kind == .macOS }
    }

    /// Converts Xcode's display variant into the value accepted by `-destination`.
    private func xcodeDestinationVariant(from variant: String?) -> String? {
        guard let variant, variant.isEmpty == false else {
            return nil
        }

        if variant.localizedCaseInsensitiveContains("designed for"),
           variant.localizedCaseInsensitiveContains("ipad") {
            return "Designed for iPad"
        }

        return variant
    }

    /// Extracts a value following a marker until the first matching end marker.
    private func extract(
        afterMarker marker: String,
        beforeMarkers: [String],
        in line: String
    ) -> String? {
        guard let range = line.range(of: marker) else {
            return nil
        }

        let afterMarkerIdx = range.upperBound
        var endIdx = line.endIndex

        for before in beforeMarkers {
            if let r = line.range(of: before, range: afterMarkerIdx..<line.endIndex) {
                if r.lowerBound < endIdx {
                    endIdx = r.lowerBound
                }
            }
        }

        let slice = line[afterMarkerIdx..<endIdx]
            .trimmingCharacters(in: .whitespaces)
        return slice.isEmpty ? nil : slice
    }
}
