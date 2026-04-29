import Foundation

/// Parses `xcodebuild -showBuildSettings` output for app product metadata.
struct XcodeBuildSettingsParser {
    /// Creates a build settings parser.
    init() {}

    /// Returns the first app product described by build settings output.
    func parseBuiltProduct(from output: String) throws -> BuiltProduct {
        let sections = buildSettingSections(from: output)

        for section in sections {
            guard let targetBuildDirectory = section["TARGET_BUILD_DIR"],
                  let fullProductName = section["FULL_PRODUCT_NAME"],
                  let bundleIdentifier = section["PRODUCT_BUNDLE_IDENTIFIER"],
                  fullProductName.hasSuffix(".app")
            else {
                continue
            }

            return BuiltProduct(
                appURL: URL(fileURLWithPath: targetBuildDirectory)
                    .appendingPathComponent(fullProductName, isDirectory: true),
                bundleIdentifier: bundleIdentifier
            )
        }

        throw SimulatorBuddyError.commandFailed(
            "Unable to resolve built app product from xcodebuild -showBuildSettings."
        )
    }

    /// Splits build settings output into per-target dictionaries.
    private func buildSettingSections(from output: String) -> [[String: String]] {
        var sections: [[String: String]] = []
        var currentSection: [String: String] = [:]

        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("Build settings for action") {
                append(section: &currentSection, to: &sections)
                continue
            }

            guard let range = line.range(of: "=") else {
                continue
            }

            let key = line[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = line[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            currentSection[key] = value
        }

        append(section: &currentSection, to: &sections)
        return sections
    }

    /// Appends a non-empty parsed section and resets it.
    private func append(section: inout [String: String], to sections: inout [[String: String]]) {
        guard section.isEmpty == false else {
            return
        }

        sections.append(section)
        section = [:]
    }
}
