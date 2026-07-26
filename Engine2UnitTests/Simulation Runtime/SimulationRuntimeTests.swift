import Testing
@testable import Engine2

struct SimulationRuntimeTests {
    @Test func constructionDistinguishesFreshAndInjectedSessionIdentity() {
        let injectedSessionID = SimulationSessionID()
        let injected = SimulationRuntime(
            worldBuilder: BasicWorldBuilder(),
            configuration: .basicGame,
            inputBaseline: nil,
            sessionID: injectedSessionID
        )
        let fresh = SimulationRuntime(
            worldBuilder: BasicWorldBuilder(),
            configuration: .basicGame,
            inputBaseline: nil
        )

        #expect(injected.sessionID == injectedSessionID)
        #expect(injected.currentCursor.sessionID == injectedSessionID)
        #expect(fresh.sessionID != injectedSessionID)
        #expect(fresh.currentCursor.sessionID == fresh.sessionID)
    }

    @Test func initBuildsEngineWorldFromBuilder() async throws {
        let builder = TestWorldBuilder(position: SIMD3<Float>(3, 4, 5))

        let simulation = SimulationRuntime(
            worldBuilder: builder,
            configuration: .basicGame,
            inputBaseline: nil
        )
        let presentationSource: any PSimulationPresentationSource = simulation

        let entity = try #require(simulation.world.positionComponents.entities.first)
        #expect(simulation.world.positionComponents[entity]?.position == SIMD3<Float>(3, 4, 5))
        #expect(SimulationRuntime.fixedTimeStep == .seconds(1.0 / 60.0))
        #expect(presentationSource.latestPresentationSnapshot.tick == .zero)
        #expect(
            presentationSource.latestPresentationSnapshot.entityPresentations.first?.position ==
                SIMD3<Float>(3, 4, 5)
        )
    }

    @Test func rebuildWorldReplacesEngineWorldUsingStoredBuilder() async throws {
        let builder = IncrementingWorldBuilder()

        let simulation = SimulationRuntime(
            worldBuilder: builder,
            configuration: .basicGame,
            inputBaseline: nil
        )
        let firstWorld = simulation.world
        let firstEntity = try #require(firstWorld.positionComponents.entities.first)

        #expect(firstWorld.positionComponents[firstEntity]?.position == SIMD3<Float>(1, 0, 0))
        #expect(builder.buildCount == 1)

        simulation.rebuildWorld(inputBaseline: nil)

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

    @Test func replacingBuilderCanDeferWorldReconstruction() throws {
        let simulation = SimulationRuntime(
            worldBuilder: TestWorldBuilder(position: SIMD3<Float>(1, 0, 0)),
            configuration: .basicGame,
            inputBaseline: nil
        )
        let originalWorld = simulation.world

        simulation.replaceWorldBuilder(
            TestWorldBuilder(position: SIMD3<Float>(9, 0, 0))
        )

        #expect(simulation.world === originalWorld)

        simulation.rebuildWorld(inputBaseline: nil)

        let entity = try #require(
            simulation.world.positionComponents.entities.first
        )
        #expect(simulation.world !== originalWorld)
        #expect(
            simulation.world.positionComponents[entity]?.position ==
            SIMD3<Float>(9, 0, 0)
        )
    }

    @Test func namedBuilderReplacementAndRebuildStartsANewWorldImmediately() throws {
        let simulation = SimulationRuntime(
            worldBuilder: TestWorldBuilder(position: SIMD3<Float>(1, 0, 0)),
            configuration: .basicGame,
            inputBaseline: nil
        )
        let originalWorld = simulation.world

        simulation.replaceWorldBuilderAndRebuild(
            TestWorldBuilder(position: SIMD3<Float>(5, 0, 0)),
            inputBaseline: nil
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

    @Test func explicitInputBaselineEstablishesWorldWithoutReplayingMotion() {
        let key = KeyboardKey.make(
            keyCode: 13,
            charactersIgnoringModifiers: "w"
        )
        let inputBaseline = InputSnapshot(
            revision: InputRevision(session: 2, sequence: 4),
            pointerPosition: SIMD2<Float>(20, 30),
            pointerMotionTotal: SIMD2<Float>(8, -3),
            scrollTotal: SIMD2<Float>(0, 5),
            pressedMouseButtons: [.left],
            pressedKeys: [key]
        )
        let simulation = SimulationRuntime(
            worldBuilder: TestWorldBuilder(position: .zero),
            configuration: .basicGame,
            inputBaseline: inputBaseline
        )

        #expect(simulation.world.input.mouse.position == SIMD2<Float>(20, 30))
        #expect(simulation.world.input.mouse.buttons == [.left])
        #expect(simulation.world.input.keyboard.keys == [key])
        #expect(simulation.world.input.mouse.delta == .zero)
        #expect(simulation.world.input.mouse.scrollDelta == .zero)

        simulation.rebuildWorld(inputBaseline: inputBaseline)

        #expect(simulation.world.input.mouse.position == SIMD2<Float>(20, 30))
        #expect(simulation.world.input.mouse.buttons == [.left])
        #expect(simulation.world.input.keyboard.keys == [key])
        #expect(simulation.world.input.mouse.delta == .zero)
        #expect(simulation.world.input.mouse.scrollDelta == .zero)
    }
}

private extension SimulationRuntimeTests {
    private struct TestWorldBuilder: PWorldBuilder {
        let position: SIMD3<Float>

        func buildWorld() -> World {
            let world = World()
            _ = Ball(in: world, materialID: .warmDielectric, position: position)
            return world
        }
    }

    private final class IncrementingWorldBuilder: PWorldBuilder {
        private(set) var buildCount = 0

        func buildWorld() -> World {
            buildCount += 1

            let world = World()
            _ = Ball(
                in: world,
                materialID: .warmDielectric,
                position: SIMD3<Float>(Float(buildCount), 0, 0)
            )
            return world
        }
    }
}
