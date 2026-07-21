/// One self-describing line in a versioned diagnostics NDJSON stream.
struct DiagnosticsStreamRecord: Codable, Equatable, Sendable {
    let schemaVersion: UInt
    let kind: DiagnosticsStreamRecordKind
    let manifest: DiagnosticsManifest?
    let sample: DiagnosticsSample?

    static func manifest(_ manifest: DiagnosticsManifest) -> DiagnosticsStreamRecord {
        DiagnosticsStreamRecord(
            schemaVersion: manifest.schemaVersion,
            kind: .manifest,
            manifest: manifest,
            sample: nil
        )
    }

    static func sample(_ sample: DiagnosticsSample) -> DiagnosticsStreamRecord {
        DiagnosticsStreamRecord(
            schemaVersion: DiagnosticsArtifactSchema.currentVersion,
            kind: .sample,
            manifest: nil,
            sample: sample
        )
    }

    func validate() throws {
        guard schemaVersion == DiagnosticsArtifactSchema.currentVersion else {
            throw DiagnosticsArtifactError.unsupportedSchemaVersion(schemaVersion)
        }

        switch kind {
        case .manifest:
            guard manifest != nil, sample == nil else {
                throw DiagnosticsArtifactError.invalidRecordShape(kind)
            }
        case .sample:
            guard manifest == nil, sample != nil else {
                throw DiagnosticsArtifactError.invalidRecordShape(kind)
            }
        }
    }
}
