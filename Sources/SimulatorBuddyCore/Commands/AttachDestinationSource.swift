/// Origin of the destination used by direct debugger attachment.
enum AttachDestinationSource: Sendable {
    /// Destination was supplied by the caller.
    case provided

    /// Destination was selected through the picker UI.
    case picker
}
