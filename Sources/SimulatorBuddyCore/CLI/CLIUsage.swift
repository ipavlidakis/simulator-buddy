import Foundation

/// Stores the command-line usage text shown for help requests.
struct CLIUsage {
    /// Full help text including built-in commands and xcodebuild replacement mode.
    let text: String

    /// Creates the canonical usage text.
    init() {
        text = """
        Usage:
          simulator-buddy list [--type simulator|device|macos|macos-catalyst|macos-designed-for-ipad|all] \
        [--format table|json] [--xcode-project <path>|--xcode-workspace <path>] [--xcode-scheme <name>]
          simulator-buddy last [--type <type>] [--scope <key>] [--format udid|json] [Xcode flags as above]
          simulator-buddy select [--type <type>] [--scope <key>] [--format udid|json] [Xcode flags as above]
          simulator-buddy debug --process-name <name> --lldb-command-file <path> [--type <type>] [--scope <key>] \
        [Xcode flags as above]
          simulator-buddy attach --process-name <name> [--destination <udid|specifier>] [--type <type>] [--scope <key>]
          simulator-buddy run --app <path> [--bundle-id <id>] [--skip-install] [--env KEY=VALUE] \
        [--destination <udid|specifier>] \
        [--type <type>] [--scope <key>] [--log-category <category>]
          simulator-buddy run (-project <path>|-workspace <path>) -scheme <name> [xcodebuild build flags] \
        [--destination <udid|specifier>] [--type <type>] [--scope <key>] [--skip-install] [--env KEY=VALUE] \
        [--log-category <category>]
          simulator-buddy <xcodebuild arguments>

          When --type is macos-catalyst or macos-designed-for-ipad, pass --xcode-scheme and one of \
        --xcode-project or --xcode-workspace. For --type all or macos, Xcode flags are optional; when \
        provided, Mac rows come from xcodebuild (with correct specifier for -destination).

          Types macos-catalyst and macos-designed-for-ipad filter My Mac run destinations for that scheme.

          --log-category can be repeated or passed comma-separated values.
        """
    }
}
