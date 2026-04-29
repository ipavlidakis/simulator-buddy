import Foundation

/// Filters Xcode-provided Mac destination variants.
public enum MacOSRecordsFilter: Sendable {
    /// Keep every Mac destination variant.
    case allVariants

    /// Keep only Catalyst rows.
    case catalyst

    /// Keep only Designed for iPad/iPhone rows.
    case designedForIPad

    /// Applies the variant filter to records that are already Mac destinations.
    public func filteredRecords(from records: [DestinationRecord]) -> [DestinationRecord] {
        switch self {
        case .allVariants:
            return records
        case .catalyst:
            return records.filter {
                ($0.macOSVariant ?? "").localizedCaseInsensitiveContains("catalyst")
            }
        case .designedForIPad:
            return records.filter {
                ($0.macOSVariant ?? "").localizedCaseInsensitiveContains("ipad")
            }
        }
    }
}
