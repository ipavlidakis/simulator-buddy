/// Origin of the destination used by build-and-run.
enum BuildDestinationSource: Sendable {
    /// Destination was supplied by the caller.
    case provided

    /// Destination was selected through the picker UI.
    case picker
}
