import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// User-directed NDJSON export of one immutable interactive app snapshot.
struct DiagnosticsSnapshotExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }

    private let data: Data

    @MainActor
    init(snapshot: DiagnosticsSnapshot, fixedStepNanoseconds: UInt64) throws {
        let measurementNanoseconds = snapshot.recentSamples.last?
            .timestamp.nanosecondsSinceSessionStart ?? 0
        let manifest = DiagnosticsManifest(
            sessionID: snapshot.sessionID,
            scenarioID: .interactiveAppSession,
            buildConfiguration: Self.buildConfiguration,
            randomSeed: 0,
            fixedStepNanoseconds: fixedStepNanoseconds,
            warmUpNanoseconds: 0,
            measurementNanoseconds: measurementNanoseconds
        )
        let encoder = DiagnosticsNDJSONEncoder()
        var data = try encoder.encode(.manifest(manifest))
        for sample in snapshot.recentSamples {
            data.append(try encoder.encode(.sample(sample)))
        }
        self.data = data
    }

    nonisolated init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    nonisolated func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }

    /// Produces the exact bytes used by both the file exporter and tests.
    nonisolated func encodedData() -> Data {
        data
    }

    private static var buildConfiguration: DiagnosticsBuildConfiguration {
#if DEBUG
        .debug
#else
        .release
#endif
    }
}
