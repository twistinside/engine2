/// Explicit failures produced while validating diagnostic stream contracts.
enum DiagnosticsArtifactError: Error, Equatable {
    case unsupportedSchemaVersion(UInt)
    case invalidRecordShape(DiagnosticsStreamRecordKind)
    case truncatedStream
    case emptyRecord(line: Int)
}
