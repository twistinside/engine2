@testable import Engine2

@MainActor
final class RecordingDiagnosticsSink: PDiagnosticsSink {
    private(set) var samples: [DiagnosticsSample] = []

    func record(_ sample: DiagnosticsSample) {
        samples.append(sample)
    }
}
