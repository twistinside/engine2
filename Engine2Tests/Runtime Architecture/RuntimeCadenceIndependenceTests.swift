import Metal
import Testing
@testable import Engine2

/// Adversarial checks for the latest-value boundary between Simulation and Render.
@MainActor
struct RuntimeCadenceIndependenceTests {
    @Test func exhaustedRenderRingCannotPreventSimulationProgress() throws {
        let sink = RecordingDiagnosticsSink()
        let diagnostics = DiagnosticsEmitter(sink: sink)
        let simulation = SimulationRuntime(diagnostics: diagnostics)
        let device = try #require(MTLCreateSystemDefaultDevice())
        let resources = try MetalResourceStore(
            device: device,
            renderAssetCatalog: .materialOnlyTestCatalog,
            frameCount: MetalRenderer.maximumFramesInFlight,
            diagnostics: diagnostics
        )
        let renderer = try MetalRenderer(
            resources: resources,
            presentationSource: simulation,
            diagnostics: diagnostics
        )

        // Retain every reusable slot exactly as indefinitely slow GPU feedback
        // would. Render must report back pressure instead of waiting on any one
        // of these semaphores from the main actor.
        for frame in resources.frames {
            #expect(frame.tryAcquire())
        }
        defer {
            for frame in resources.frames {
                frame.markAvailable()
            }
        }

        let acquisition = renderer.acquireNextFrameIfAvailable(
            frameSequence: .zero
        )
        #expect(acquisition?.frameSlot == nil)

        // A large deterministic burst makes the important assertion concrete:
        // no Render completion is needed for Simulation to keep advancing.
        let startingTick = simulation.engine.completedTick.rawValue
        simulation.runDiagnosticFixedSteps(count: 600)
        #expect(simulation.engine.completedTick.rawValue == startingTick + 600)
        #expect(simulation.latestPresentationSnapshot.tick == simulation.engine.completedTick)

        let acquisitionSamples = sink.samples.compactMap { sample -> FrameSlotWaitDiagnostics? in
            guard case let .frameSlotWait(payload) = sample.payload else {
                return nil
            }
            return payload
        }
        #expect(acquisitionSamples.last?.result == .unavailable)
    }

    @Test func frozenSimulationPublicationCannotPreventRenderProjection() throws {
        let sink = RecordingDiagnosticsSink()
        let diagnostics = DiagnosticsEmitter(sink: sink)
        let simulation = SimulationRuntime(diagnostics: diagnostics)
        let device = try #require(MTLCreateSystemDefaultDevice())
        let resources = try MetalResourceStore(
            device: device,
            renderAssetCatalog: .materialOnlyTestCatalog,
            frameCount: 1,
            diagnostics: diagnostics
        )
        let renderer = try MetalRenderer(
            resources: resources,
            presentationSource: simulation,
            diagnostics: diagnostics
        )

        simulation.runDiagnosticFixedSteps(count: 7)
        simulation.pauseSimulation()
        let frozenTick = simulation.latestPresentationSnapshot.tick

        // No new Simulation publication is produced during these Render-owned
        // projections. Latest-value semantics permit any number of render
        // frames to reuse one completed immutable snapshot without waiting for
        // a newer tick.
        let projectedFrames = (0..<600).map { _ in
            renderer.projectLatestPresentation()
        }

        #expect(projectedFrames.count == 600)
        #expect(projectedFrames.allSatisfy { $0.sourceTick == frozenTick })
        #expect(simulation.engine.completedTick == frozenTick)

        let projectionSamples = sink.samples.filter { sample in
            if case .renderProjection = sample.payload {
                return true
            }
            return false
        }
        #expect(projectionSamples.count == 600)
    }
}
