import Testing
import Foundation
@testable import Engine2

@MainActor
struct RenderDiagnosticsEmitterTests {
    @Test func gpuCompletionCorrelatesSuccessFailureAndDelayedFeedback() async throws {
        let sink = RecordingDiagnosticsSink()
        let emitter = DiagnosticsEmitter(sink: sink)
        let success = emitter.beginGPUFrame(
            submissionID: RenderSubmissionID(rawValue: 3),
            frameSequence: RenderFrameSequence(rawValue: 5),
            sourceTick: SimulationTick(rawValue: 8),
            frameSlot: 2
        )
        #expect(sink.samples.isEmpty)

        success.complete(feedbackError: nil)
        try await waitForSampleCount(1, in: sink)
        let successSample = try #require(sink.samples.last)
        guard case let .gpuFrame(successPayload) = successSample.payload else {
            Issue.record("Expected completed GPU feedback")
            return
        }
        #expect(successPayload.submissionID == RenderSubmissionID(rawValue: 3))
        #expect(successPayload.frameSequence == RenderFrameSequence(rawValue: 5))
        #expect(successPayload.sourceTick == SimulationTick(rawValue: 8))
        #expect(successPayload.frameSlot == 2)
        #expect(successPayload.result == .completed)

        let failure = emitter.beginGPUFrame(
            submissionID: RenderSubmissionID(rawValue: 4),
            frameSequence: RenderFrameSequence(rawValue: 6),
            sourceTick: SimulationTick(rawValue: 9),
            frameSlot: 0
        )
        failure.complete(
            feedbackError: NSError(domain: "RenderDiagnosticsEmitterTests", code: 9)
        )
        try await waitForSampleCount(2, in: sink)
        let failureSample = try #require(sink.samples.last)
        guard case let .gpuFrame(failurePayload) = failureSample.payload else {
            Issue.record("Expected failed GPU feedback")
            return
        }
        #expect(failurePayload.result == .failed)
        #expect(failurePayload.errorType?.contains("NSError") == true)
    }

    @Test func cpuMeasurementsPreserveFrameIdentityAndExistingWorkCounts() throws {
        let sink = RecordingDiagnosticsSink()
        let emitter = DiagnosticsEmitter(sink: sink)
        let frameSequence = RenderFrameSequence(rawValue: 7)
        let sourceTick = SimulationTick(rawValue: 11)

        let acquired = emitter.measureFrameSlotWait(
            frameSequence: frameSequence,
            frameSlot: 1
        ) {
            true
        }
        let encodeMeasurement = emitter.beginFrameEncode(
            frameSequence: frameSequence,
            sourceTick: sourceTick
        )
        let encodedCounts = RenderDrawCounts(drawCount: 3, submeshCount: 3)
        emitter.endFrameEncode(
            encodeMeasurement,
            frameSequence: frameSequence,
            sourceTick: sourceTick,
            counts: encodedCounts
        )
        emitter.measureRenderFrameCPU(frameSequence: frameSequence) {
            RenderFrameCPUDiagnostics(
                frameSequence: frameSequence,
                sourceTick: sourceTick,
                didSourceTickChange: true,
                submittedInstanceCount: 2,
                renderPassCount: 2,
                drawCount: encodedCounts.drawCount,
                submeshCount: encodedCounts.submeshCount,
                wasTruncated: false,
                result: .submitted,
                durationNanoseconds: 0
            )
        }

        #expect(sink.samples.count == 3)
        guard case let .frameSlotWait(wait) = sink.samples[0].payload,
              case let .frameEncode(encode) = sink.samples[1].payload,
              case let .renderFrameCPU(cpu) = sink.samples[2].payload else {
            Issue.record("Expected the three Render CPU sample kinds")
            return
        }
        #expect(wait.frameSequence == frameSequence)
        #expect(wait.frameSlot == 1)
        #expect(wait.result == .acquired)
        #expect(acquired)
        #expect(encode.sourceTick == sourceTick)
        #expect(encode.renderPassCount == 2)
        #expect(encode.drawCount == 3)
        #expect(cpu.result == .submitted)
        #expect(cpu.didSourceTickChange)
        #expect(cpu.submittedInstanceCount == 2)
    }

    private func waitForSampleCount(
        _ count: Int,
        in sink: RecordingDiagnosticsSink
    ) async throws {
        for _ in 0..<100 where sink.samples.count < count {
            await Task.yield()
        }
        #expect(sink.samples.count >= count)
    }
}
