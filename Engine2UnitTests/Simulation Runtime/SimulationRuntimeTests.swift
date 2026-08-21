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
        let expectedPosition = SIMD3<Double>(3, 4, 5)
        let builder = TestWorldBuilder(position: expectedPosition)

        let simulation = SimulationRuntime(
            worldBuilder: builder,
            configuration: .basicGame,
            inputBaseline: nil
        )
        let presentationSource: any PSimulationPresentationSource = simulation

        let entity = try #require(simulation.world.positionComponents.entities.first)
        #expect(simulation.world.positionComponents[entity]?.position == expectedPosition)
        #expect(SimulationRuntime.fixedTimeStep == .seconds(1.0 / 60.0))
        #expect(presentationSource.latestPresentationSnapshot.tick == .zero)
        #expect(
            presentationSource.latestPresentationSnapshot.entityPresentations.first?.position ==
                expectedPosition.singlePrecision
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

        #expect(firstWorld.positionComponents[firstEntity]?.position == SIMD3<Double>(1, 0, 0))
        #expect(builder.buildCount == 1)

        simulation.rebuildWorld(inputBaseline: nil)

        let secondEntity = try #require(simulation.world.positionComponents.entities.first)
        let secondExpectedPosition = SIMD3<Double>(2, 0, 0)

        #expect(builder.buildCount == 2)
        #expect(simulation.world !== firstWorld)
        #expect(simulation.world.positionComponents[secondEntity]?.position == secondExpectedPosition)
        #expect(simulation.latestPresentationSnapshot.tick == .zero)
        #expect(
            simulation.latestPresentationSnapshot.entityPresentations.first?.position ==
                secondExpectedPosition.singlePrecision
        )
    }

    @Test func replacingBuilderCanDeferWorldReconstruction() throws {
        let initialBuilder = TestWorldBuilder(position: SIMD3<Double>(1, 0, 0))
        let simulation = SimulationRuntime(
            worldBuilder: initialBuilder,
            configuration: .basicGame,
            inputBaseline: nil
        )
        let originalWorld = simulation.world

        let replacementPosition = SIMD3<Double>(9, 0, 0)
        let replacementBuilder = TestWorldBuilder(position: replacementPosition)
        simulation.replaceWorldBuilder(replacementBuilder)

        #expect(simulation.world === originalWorld)

        simulation.rebuildWorld(inputBaseline: nil)

        let entity = try #require(
            simulation.world.positionComponents.entities.first
        )
        #expect(simulation.world !== originalWorld)
        #expect(
            simulation.world.positionComponents[entity]?.position ==
            replacementPosition
        )
    }

    @Test func namedBuilderReplacementAndRebuildStartsANewWorldImmediately() throws {
        let initialBuilder = TestWorldBuilder(position: SIMD3<Double>(1, 0, 0))
        let simulation = SimulationRuntime(
            worldBuilder: initialBuilder,
            configuration: .basicGame,
            inputBaseline: nil
        )
        let originalWorld = simulation.world

        let replacementPosition = SIMD3<Double>(5, 0, 0)
        let replacementBuilder = TestWorldBuilder(position: replacementPosition)
        simulation.replaceWorldBuilderAndRebuild(
            replacementBuilder,
            inputBaseline: nil
        )

        let entity = try #require(
            simulation.world.positionComponents.entities.first
        )
        #expect(simulation.world !== originalWorld)
        #expect(
            simulation.world.positionComponents[entity]?.position ==
            replacementPosition
        )
    }

    @Test func explicitInputBaselineEstablishesWorldWithoutReplayingMotion() {
        let key = KeyboardKey(
            keyCode: 13,
            charactersIgnoringModifiers: "w"
        )
        let pointerPosition = SIMD2<Float>(20, 30)
        let inputBaseline = InputSnapshot(
            revision: InputRevision(session: 2, sequence: 4),
            pointerPosition: pointerPosition,
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

        #expect(simulation.world.input.mouse.position == pointerPosition)
        #expect(simulation.world.input.mouse.buttons == [.left])
        #expect(simulation.world.input.keyboard.keys == [key])
        #expect(simulation.world.input.mouse.delta == .zero)
        #expect(simulation.world.input.mouse.scrollDelta == .zero)

        simulation.rebuildWorld(inputBaseline: inputBaseline)

        #expect(simulation.world.input.mouse.position == pointerPosition)
        #expect(simulation.world.input.mouse.buttons == [.left])
        #expect(simulation.world.input.keyboard.keys == [key])
        #expect(simulation.world.input.mouse.delta == .zero)
        #expect(simulation.world.input.mouse.scrollDelta == .zero)
    }
}

private extension SimulationRuntimeTests {
    private struct TestWorldBuilder: PWorldBuilder {
        let position: SIMD3<Double>

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
            let position = SIMD3<Double>(Double(buildCount), 0, 0)
            _ = Ball(
                in: world,
                materialID: .warmDielectric,
                position: position
            )
            return world
        }
    }
}
