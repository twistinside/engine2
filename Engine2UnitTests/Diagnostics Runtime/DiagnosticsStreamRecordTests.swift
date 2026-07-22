import Foundation
import Testing
@testable import Engine2

struct DiagnosticsStreamRecordTests {
    @Test func validationRejectsManifestKindWithBothOrNeitherPayloads() {
        let manifest = makeManifest()
        let sample = makeSample()
        let both = DiagnosticsStreamRecord(
            schemaVersion: DiagnosticsArtifactSchema.currentVersion,
            kind: .manifest,
            manifest: manifest,
            sample: sample
        )
        let neither = DiagnosticsStreamRecord(
            schemaVersion: DiagnosticsArtifactSchema.currentVersion,
            kind: .manifest,
            manifest: nil,
            sample: nil
        )

        #expect(throws: DiagnosticsArtifactError.invalidRecordShape(.manifest)) {
            try both.validate()
        }
        #expect(throws: DiagnosticsArtifactError.invalidRecordShape(.manifest)) {
            try neither.validate()
        }
    }

    @Test func validationRejectsSampleKindWithWrongPayloadShape() {
        let record = DiagnosticsStreamRecord(
            schemaVersion: DiagnosticsArtifactSchema.currentVersion,
            kind: .sample,
            manifest: makeManifest(),
            sample: nil
        )

        #expect(throws: DiagnosticsArtifactError.invalidRecordShape(.sample)) {
            try record.validate()
        }
    }

    @Test func decoderReportsTheExactBlankRecordLine() throws {
        var data = try DiagnosticsNDJSONEncoder().encode(.manifest(makeManifest()))
        data.append(0x0A)

        #expect(throws: DiagnosticsArtifactError.emptyRecord(line: 2)) {
            try DiagnosticsNDJSONDecoder().decode(data)
        }
    }

    @Test func encoderPropagatesWriterFailureUnchanged() {
        #expect(throws: WriterFailure.refused) {
            try DiagnosticsNDJSONEncoder().write(.sample(makeSample())) { _ in
                throw WriterFailure.refused
            }
        }
    }

    @Test func concatenatedRecordsDecodeInOriginalStreamOrder() throws {
        let records: [DiagnosticsStreamRecord] = [
            .manifest(makeManifest()),
            .sample(makeSample(timestamp: 1)),
            .sample(makeSample(timestamp: 2))
        ]
        var data = Data()
        let encoder = DiagnosticsNDJSONEncoder()
        for record in records {
            data.append(try encoder.encode(record))
        }

        #expect(try DiagnosticsNDJSONDecoder().decode(data) == records)
    }

    private enum WriterFailure: Error, Equatable {
        case refused
    }

    private func makeManifest() -> DiagnosticsManifest {
        DiagnosticsManifest(
            sessionID: DiagnosticsSessionID(),
            scenarioID: .interactiveAppSession,
            buildConfiguration: .debug,
            randomSeed: 0,
            fixedStepNanoseconds: 1,
            warmUpNanoseconds: 0,
            measurementNanoseconds: 1
        )
    }

    private func makeSample(timestamp: UInt64 = 0) -> DiagnosticsSample {
        DiagnosticsSample(
            sessionID: DiagnosticsSessionID(),
            timestamp: DiagnosticsTimestamp(nanosecondsSinceSessionStart: timestamp),
            category: .simulationLoop,
            payload: .simulationStep(
                SimulationStepDiagnostics(
                    tick: SimulationTick(rawValue: timestamp),
                    didRunSimulationSystems: true,
                    durationNanoseconds: 1
                )
            )
        )
    }
}
