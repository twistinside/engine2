import XCTest
@testable import Engine2

#if PERFORMANCE
/// Release-only measurements for Engine2's stable diagnostic workloads.
///
/// These tests deliberately live behind the `Engine2Performance` test plan so
/// normal correctness runs do not collect noisy timing data. Baselines belong
/// to a reviewed machine class; the assertions here only protect workload
/// structure while XCTest records time, CPU, memory, and selected signposts.
nonisolated final class DiagnosticsPerformanceTests: XCTestCase {
    @MainActor
    func testBaselineFixedSteps() {
        let metrics: [XCTMetric] = [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()]

        measure(metrics: metrics, options: measurementOptions) {
            let engine = makeEngine()
            for _ in 0..<600 {
                engine.step()
            }
            XCTAssertEqual(engine.completedTick, SimulationTick(rawValue: 600))
        }
    }

    @MainActor
    func testInvariantSystemSchedule() {
        measure(metrics: [XCTClockMetric(), XCTCPUMetric()], options: measurementOptions) {
            var world = BasicWorldBuilder().buildWorld()
            let movement = SMovement()
            let rotation = SRotation()

            for _ in 0..<1_000 {
                movement.update(world: &world, deltaTime: 1 / 60)
                rotation.update(world: &world, deltaTime: 1 / 60)
            }
            XCTAssertEqual(world.positionComponents.dense.count, 6)
        }
    }

    @MainActor
    func testPresentationCapture() {
        let world = BasicWorldBuilder().buildWorld()
        var lastSnapshot = SimulationPresentationSnapshot.capture(from: world, at: .zero)

        measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()], options: measurementOptions) {
            for rawTick in 1...1_000 {
                lastSnapshot = SimulationPresentationSnapshot.capture(
                    from: world,
                    at: SimulationTick(rawValue: UInt64(rawTick))
                )
            }
        }

        XCTAssertEqual(lastSnapshot.entityPresentations.count, 6)
    }

    @MainActor
    func testRenderProjection() {
        let snapshot = SimulationPresentationSnapshot.capture(
            from: BasicWorldBuilder().buildWorld(),
            at: SimulationTick(rawValue: 1)
        )
        var lastFrame = RenderFrame.empty

        measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()], options: measurementOptions) {
            for _ in 0..<1_000 {
                lastFrame = RenderFrame.project(from: snapshot)
            }
        }

        XCTAssertEqual(lastFrame.instances.count, 6)
    }

    @MainActor
    func testSimulationStepSignpost() {
        let signpostMetric = XCTOSSignpostMetric(
            subsystem: DiagnosticsOSHandles.subsystem,
            category: DiagnosticsCategory.simulationLoop.rawValue,
            name: DiagnosticsSignpostName.simulationStep.rawValue
        )
        let engine = makeEngine()

        measure(metrics: [signpostMetric], options: measurementOptions) {
            engine.step()
        }
    }

    @MainActor private var measurementOptions: XCTMeasureOptions {
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        return options
    }

    @MainActor private func makeEngine() -> Engine {
        let engine = Engine(
            world: BasicWorldBuilder().buildWorld(),
            diagnostics: DiagnosticsEmitter()
        )
        engine.isSimulationRunning = true
        return engine
    }
}
#endif
