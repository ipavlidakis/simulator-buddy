import Foundation

/// Scans raw xcodebuild arguments while respecting option values.
struct XcodebuildArgumentScanner {
    /// xcodebuild options whose next token is consumed as an option value.
    private let optionsWithValues: Set<String> = [
        "-archivePath",
        "-clonedSourcePackagesDirPath",
        "-configuration",
        "-derivedDataPath",
        "-destination",
        "-destination-timeout",
        "-enableAddressSanitizer",
        "-enableCodeCoverage",
        "-enableThreadSanitizer",
        "-exportOptionsPlist",
        "-exportPath",
        "-only-testing",
        "-parallel-testing-enabled",
        "-project",
        "-resultBundlePath",
        "-scheme",
        "-sdk",
        "-skip-testing",
        "-testLanguage",
        "-testPlan",
        "-testRegion",
        "-toolchain",
        "-workspace",
        "-xcconfig",
    ]

    /// Creates an xcodebuild argument scanner.
    init() {}

    /// Returns a supplied `-destination` value when present.
    func destinationArgument(in arguments: [String]) -> String? {
        var skipNext = false

        for (index, argument) in arguments.enumerated() {
            if skipNext {
                skipNext = false
                continue
            }

            if argument == "-destination" {
                let valueIndex = index + 1
                return arguments.indices.contains(valueIndex) ? arguments[valueIndex] : nil
            }

            if argument.hasPrefix("-destination=") {
                return String(argument.dropFirst("-destination=".count))
            }

            if argument.hasPrefix("-") {
                skipNext = optionRequiresValue(argument)
            }
        }

        return nil
    }

    /// Returns positional xcodebuild actions.
    func actions(in arguments: [String]) -> [String] {
        var actions: [String] = []
        var skipNext = false

        for argument in arguments {
            if skipNext {
                skipNext = false
                continue
            }

            if argument.hasPrefix("-") {
                skipNext = optionRequiresValue(argument)
                continue
            }

            actions.append(argument)
        }

        return actions
    }

    /// Inserts a destination before the first positional action.
    func insertingDestination(_ destination: String, into arguments: [String]) -> [String] {
        var injectedArguments = arguments
        injectedArguments.insert(contentsOf: ["-destination", destination], at: destinationInsertionIndex(in: arguments))
        return injectedArguments
    }

    /// Returns arguments with positional actions removed.
    func removingActions(from arguments: [String]) -> [String] {
        var filteredArguments: [String] = []
        var skipNext = false

        for argument in arguments {
            if skipNext {
                filteredArguments.append(argument)
                skipNext = false
                continue
            }

            if argument.hasPrefix("-") {
                filteredArguments.append(argument)
                skipNext = optionRequiresValue(argument)
                continue
            }
        }

        return filteredArguments
    }

    /// Ensures arguments include a build action.
    func ensuringBuildAction(in arguments: [String]) -> [String] {
        guard actions(in: arguments).contains("build") == false else {
            return arguments
        }

        return arguments + ["build"]
    }

    /// Returns true when actions are compatible with build-and-run.
    func supportsBuildAndRunActions(in arguments: [String]) -> Bool {
        actions(in: arguments).allSatisfy { action in
            action == "build" || action == "clean"
        }
    }

    /// Returns the index where injected destination belongs.
    private func destinationInsertionIndex(in arguments: [String]) -> Int {
        var skipNext = false

        for (index, argument) in arguments.enumerated() {
            if skipNext {
                skipNext = false
                continue
            }

            if argument.hasPrefix("-") {
                skipNext = optionRequiresValue(argument)
                continue
            }

            return index
        }

        return arguments.count
    }

    /// Returns true when an option consumes the following token as its value.
    private func optionRequiresValue(_ argument: String) -> Bool {
        guard argument.contains("=") == false else {
            return false
        }

        return optionsWithValues.contains(argument)
    }
}
