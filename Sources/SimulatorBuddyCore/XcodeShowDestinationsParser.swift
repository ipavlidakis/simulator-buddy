import Foundation

/// Parses `xcodebuild -showdestinations` output for local Mac run destinations.
public enum XcodeShowDestinationsParser {
    /// One row per `platform:macOS` destination without an `error:` clause.
    public static func parseMacOSRunDestinations(from stdout: String) -> [DestinationRecord] {
        stdout
            .split(separator: "\n", omittingEmptySubsequences: false)
            .compactMap { lineRaw in
                let line = String(lineRaw).trimmingCharacters(in: .whitespaces)
                guard line.contains("platform:macOS") else {
                    return nil
                }

                if line.contains(" error:") {
                    return nil
                }

                guard let id = extract(afterMarker: "id:", beforeMarkers: [", name:", "}"], in: line),
                      id.isEmpty == false
                else {
                    return nil
                }

                let arch = extract(
                    afterMarker: "arch:",
                    beforeMarkers: [", variant:", ", id:", ", name:"],
                    in: line
                )?.trimmingCharacters(in: .whitespaces)

                let variant = extract(
                    afterMarker: "variant:",
                    beforeMarkers: [", id:", ", name:"],
                    in: line
                )?.trimmingCharacters(in: .whitespaces)

                let nameToken = extract(
                    afterMarker: "name:",
                    beforeMarkers: ["}"],
                    in: line
                )?.trimmingCharacters(in: .whitespaces) ?? "Mac"

                let displayName: String
                if let variant, variant.isEmpty == false {
                    displayName = "\(nameToken) - \(variant)"
                } else {
                    displayName = nameToken
                }

                var specifierParts = ["platform=macOS"]
                if let arch, arch.isEmpty == false {
                    specifierParts.append("arch=\(arch)")
                }
                if let variant, variant.isEmpty == false {
                    specifierParts.append("variant=\(variant)")
                }
                specifierParts.append("id=\(id)")
                let specifier = specifierParts.joined(separator: ",")

                return DestinationRecord(
                    kind: .macOS,
                    udid: id,
                    name: displayName,
                    runtime: variant ?? "macOS",
                    state: .available,
                    stateDescription: "Available",
                    lastBootedAt: nil,
                    sourceIdentifier: nil,
                    macOSVariant: variant,
                    xcodeDestinationSpecifier: specifier
                )
            }
    }

    private static func extract(
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
