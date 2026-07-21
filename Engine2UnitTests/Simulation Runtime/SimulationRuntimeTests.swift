import Testing
@testable import Engine2

struct SimulationRuntimeTests {
    @Test @MainActor func initBuildsEngineWorldFromBuilder() async throws {
        let builder = TestWorldBuilder(position: SIMD3<Float>(3, 4, 5))

        let simulation = SimulationRuntime(worldBuilder: builder)
        let presentationSource: any PSimulationPresentationSource = simulation

        let entity = try #require(simulation.world.positionComponents.entities.first)
        #expect(simulation.world.positionComponents[entity]?.position == SIMD3<Float>(3, 4, 5))
        #expect(simulation.state.fixedTimeStep == .seconds(1.0 / 60.0))
        #expect(simulation.state.isRunning == false)
        #expect(presentationSource.latestPresentationSnapshot.tick == .zero)
        #expect(
            presentationSource.latestPresentationSnapshot.entityPresentations.first?.position ==
                SIMD3<Float>(3, 4, 5)
        )
    }

    @Test @MainActor func rebuildWorldReplacesEngineWorldUsingStoredBuilder() async throws {
        let builder = IncrementingWorldBuilder()

        let simulation = SimulationRuntime(worldBuilder: builder)
        let firstWorld = simulation.world
        let firstEntity = try #require(firstWorld.positionComponents.entities.first)

        #expect(firstWorld.positionComponents[firstEntity]?.position == SIMD3<Float>(1, 0, 0))
        #expect(builder.buildCount == 1)

        simulation.rebuildWorld()

        let secondEntity = try #require(simulation.world.positionComponents.entities.first)

        #expect(builder.buildCount == 2)
        #expect(simulation.world !== firstWorld)
        #expect(simulation.world.positionComponents[secondEntity]?.position == SIMD3<Float>(2, 0, 0))
        #expect(simulation.latestPresentationSnapshot.tick == .zero)
        #expect(
            simulation.latestPresentationSnapshot.entityPresentations.first?.position ==
                SIMD3<Float>(2, 0, 0)
        )
    }

    @Test @MainActor func publicationReportsRenderableAndPublishedCounts() throws {
        let sink = RecordingDiagnosticsSink()
        let diagnostics = DiagnosticsEmitter(sink: sink)
        let simulation = SimulationRuntime(
            worldBuilder: TestWorldBuilder(position: .zero),
            diagnostics: diagnostics
        )

        simulation.rebuildWorld()

        let captures = sink.samples.compactMap { sample -> PresentationSnapshotDiagnostics? in
            guard case let .presentationSnapshot(payload) = sample.payload else {
                return nil
            }
            return payload
        }
        #expect(captures.count == 2)
        let initialCapture = try #require(captures.first)
        let rebuiltCapture = try #require(captures.last)
        #expect(initialCapture.tick == .zero)
        #expect(initialCapture.renderableRowCount == 1)
        #expect(initialCapture.publishedPresentationCount == 1)
        #expect(rebuiltCapture.tick == .zero)
        #expect(rebuiltCapture.renderableRowCount == 1)
        #expect(rebuiltCapture.publishedPresentationCount == 1)
        #expect(simulation.latestPresentationSnapshot.entityPresentations.count == 1)
    }

    @Test @MainActor func constructionAndRebuildReportExactRuntimeInventory() throws {
        let sink = RecordingDiagnosticsSink()
        let diagnostics = DiagnosticsEmitter(sink: sink)
        let simulation = SimulationRuntime(
            worldBuilder: TestWorldBuilder(position: .zero),
            diagnostics: diagnostics
        )

        simulation.rebuildWorld()

        let inventories = sink.samples.compactMap { sample -> SimulationRuntimeInventoryDiagnostics? in
            guard case let .simulationRuntimeInventory(payload) = sample.payload else {
                return nil
            }
            return payload
        }
        #expect(inventories.count == 2)
        let initialInventory = try #require(inventories.first)
        let rebuiltInventory = try #require(inventories.last)
        let expectedAlwaysSystems: [SimulationSystemID] = [
            .inputMapping,
            .cameraInput,
            .inputHistory,
            .inputCleanup
        ]
        let expectedSimulationSystems: [SimulationSystemID] = [
            .accelerationIntent,
            .movement,
            .rotation
        ]

        #expect(initialInventory.alwaysSystemIDs == expectedAlwaysSystems)
        #expect(initialInventory.simulationSystemIDs == expectedSimulationSystems)
        #expect(initialInventory.presentationEntityCount == 1)
        #expect(initialInventory.componentStores.map(\.storeID) == ComponentStoreDiagnosticsID.allCases)
        #expect(rebuiltInventory == initialInventory)
    }

    @Test @MainActor func startAndStopDriveExposedState() async throws {
        let simulation = SimulationRuntime(
            worldBuilder: TestWorldBuilder(position: .zero),
            pollInterval: .seconds(60)
        )

        #expect(simulation.state.isRunning == false)

        simulation.start()
        #expect(simulation.state.isRunning == true)
        #expect(simulation.state.isLoopRunning == true)

        simulation.stop()
        #expect(simulation.state.isRunning == false)
        #expect(simulation.state.isLoopRunning == false)
    }

    @Test @MainActor func replacingBuilderCanDeferWorldReconstruction() throws {
        let simulation = SimulationRuntime(
            worldBuilder: TestWorldBuilder(position: SIMD3<Float>(1, 0, 0))
        )
        let originalWorld = simulation.world

        simulation.replaceWorldBuilder(
            TestWorldBuilder(position: SIMD3<Float>(9, 0, 0)),
            rebuildWorldImmediately: false
        )

        #expect(simulation.world === originalWorld)

        simulation.rebuildWorld()

        let entity = try #require(
            simulation.world.positionComponents.entities.first
        )
        #expect(simulation.world !== originalWorld)
        #expect(
            simulation.world.positionComponents[entity]?.position ==
            SIMD3<Float>(9, 0, 0)
        )
    }

    @Test @MainActor func replacingBuilderRebuildsImmediatelyByDefault() throws {
        let simulation = SimulationRuntime(
            worldBuilder: TestWorldBuilder(position: SIMD3<Float>(1, 0, 0))
        )
        let originalWorld = simulation.world

        simulation.replaceWorldBuilder(
            TestWorldBuilder(position: SIMD3<Float>(5, 0, 0))
        )

        let entity = try #require(
            simulation.world.positionComponents.entities.first
        )
        #expect(simulation.world !== originalWorld)
        #expect(
            simulation.world.positionComponents[entity]?.position ==
            SIMD3<Float>(5, 0, 0)
        )
    }

    @Test @MainActor func inputSourceEstablishesWorldBaselineWithoutReplayingMotion() {
        let key = KeyboardKey.make(
            keyCode: 13,
            charactersIgnoringModifiers: "w"
        )
        let inputSource = RuntimeTestInputSnapshotSource(
            snapshot: InputSnapshot(
                revision: InputRevision(session: 2, sequence: 4),
                pointerPosition: SIMD2<Float>(20, 30),
                pointerMotionTotal: SIMD2<Float>(8, -3),
                scrollTotal: SIMD2<Float>(0, 5),
                pressedMouseButtons: [.left],
                pressedKeys: [key]
            )
        )
        let simulation = SimulationRuntime(
            worldBuilder: TestWorldBuilder(position: .zero),
            inputSource: inputSource
        )

        #expect(simulation.world.input.mouse.position == SIMD2<Float>(20, 30))
        #expect(simulation.world.input.mouse.buttons == [.left])
        #expect(simulation.world.input.keyboard.keys == [key])
        #expect(simulation.world.input.mouse.delta == .zero)
        #expect(simulation.world.input.mouse.scrollDelta == .zero)

        simulation.rebuildWorld()

        #expect(simulation.world.input.mouse.position == SIMD2<Float>(20, 30))
        #expect(simulation.world.input.mouse.buttons == [.left])
        #expect(simulation.world.input.keyboard.keys == [key])
        #expect(simulation.world.input.mouse.delta == .zero)
        #expect(simulation.world.input.mouse.scrollDelta == .zero)
    }
}

@MainActor
private final class RuntimeTestInputSnapshotSource: PInputSnapshotSource {
    var latestInputSnapshot: InputSnapshot

    init(snapshot: InputSnapshot) {
        latestInputSnapshot = snapshot
    }
}

private struct TestWorldBuilder: PWorldBuilder {
    let position: SIMD3<Float>

    func buildWorld() -> World {
        let world = World()
        _ = Ball(in: world, position: position)
        return world
    }
}

private final class IncrementingWorldBuilder: PWorldBuilder {
    private(set) var buildCount = 0

    func buildWorld() -> World {
        buildCount += 1

        let world = World()
        _ = Ball(in: world, position: SIMD3<Float>(Float(buildCount), 0, 0))
        return world
    }
}
