import Testing
@testable import Engine2

@MainActor
struct RenderDiagnosticsEmitterTests {
    @Test func cpuMeasurementsPreserveFrameIdentityAndExistingWorkCounts() throws {
        let sink = RecordingDiagnosticsSink()
        let emitter = DiagnosticsEmitter(sink: sink)
        let frameSequence = RenderFrameSequence(rawValue: 7)
        let sourceTick = SimulationTick(rawValue: 11)

        emitter.measureFrameSlotWait(frameSequence: frameSequence, frameSlot: 1) {}
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
        #expect(encode.sourceTick == sourceTick)
        #expect(encode.renderPassCount == 2)
        #expect(encode.drawCount == 3)
        #expect(cpu.result == .submitted)
        #expect(cpu.didSourceTickChange)
        #expect(cpu.submittedInstanceCount == 2)
    }
}
