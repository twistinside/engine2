import Foundation
import Testing
@testable import Engine2

struct DiagnosticsArtifactTests {
    @Test func manifestEncodingMatchesCheckedInGoldenFixture() throws {
        let manifest = DiagnosticsManifest(
            sessionID: DiagnosticsSessionID(
                rawValue: try #require(
                    UUID(uuidString: "2F605D0B-B7C2-44A7-8D4F-8E73AB23ACCB")
                )
            ),
            scenarioID: .baselineSixBall,
            buildConfiguration: .release,
            randomSeed: 42,
            fixedStepNanoseconds: 16_666_667,
            warmUpNanoseconds: 2_000_000_000,
            measurementNanoseconds: 15_000_000_000
        )
        let encoded = try DiagnosticsNDJSONEncoder().encode(.manifest(manifest))
        let fixtureURL = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .appending(path: "Fixtures/manifest-v1.ndjson")
        let fixture = try Data(contentsOf: fixtureURL)

        #expect(encoded == fixture)
        #expect(try DiagnosticsNDJSONDecoder().decode(encoded) == [.manifest(manifest)])
    }

    @Test func sampleRoundTripsThroughStreamingWriter() throws {
        let sessionID = DiagnosticsSessionID()
        let sample = DiagnosticsSample(
            sessionID: sessionID,
            timestamp: .zero,
            category: .simulationLoop,
            payload: .simulationStep(
                SimulationStepDiagnostics(
                    tick: SimulationTick(rawValue: 1),
                    didRunSimulationSystems: true,
                    durationNanoseconds: 99
                )
            )
        )
        var output = Data()

        try DiagnosticsNDJSONEncoder().write(.sample(sample)) { data in
            output.append(data)
        }

        #expect(try DiagnosticsNDJSONDecoder().decode(output) == [.sample(sample)])
    }

    @Test func decoderRejectsUnknownVersionsAndTruncatedStreams() throws {
        let manifest = DiagnosticsManifest(
            schemaVersion: 99,
            sessionID: DiagnosticsSessionID(),
            scenarioID: .baselineSixBall,
            buildConfiguration: .debug,
            randomSeed: 0,
            fixedStepNanoseconds: 1,
            warmUpNanoseconds: 0,
            measurementNanoseconds: 1
        )
        let invalidVersionRecord = DiagnosticsStreamRecord(
            schemaVersion: 99,
            kind: .manifest,
            manifest: manifest,
            sample: nil
        )
        let rawEncoder = JSONEncoder()
        var unknownVersionData = try rawEncoder.encode(invalidVersionRecord)
        unknownVersionData.append(0x0A)

        #expect(throws: DiagnosticsArtifactError.unsupportedSchemaVersion(99)) {
            try DiagnosticsNDJSONDecoder().decode(unknownVersionData)
        }
        #expect(throws: DiagnosticsArtifactError.truncatedStream) {
            try DiagnosticsNDJSONDecoder().decode(Data("{}".utf8))
        }
    }
}
