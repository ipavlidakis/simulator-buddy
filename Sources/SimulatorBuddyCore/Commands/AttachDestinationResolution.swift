/// Result of resolving the destination used for direct debugger attachment.
struct AttachDestinationResolution: Sendable {
    /// Destination metadata resolved successfully.
    let record: DestinationRecord

    /// Origin of the resolved destination.
    let source: AttachDestinationSource

    /// Creates an attach destination resolution.
    init(record: DestinationRecord, source: AttachDestinationSource) {
        self.record = record
        self.source = source
    }
}
