import Testing
import simd
@testable import Engine2

struct TerrestrialPlanetWorldBuilderTests {
    private static let planetID = EntityID(index: 0, generation: 0)

    @Test func seedsOneStaticPlanetFramedByTheProofCamera() {
        let world = TerrestrialPlanetWorldBuilder().buildWorld()

        #expect(world.camera == TerrestrialPlanetWorldBuilder.proofCamera)
        #expect(world.positionComponents.entities == [Self.planetID])
        #expect(world.rotationComponents.entities == [Self.planetID])
        #expect(world.scaleComponents.entities == [Self.planetID])
        #expect(world.renderableComponents.entities == [Self.planetID])
        #expect(world.selectableComponents.entities == [Self.planetID])
        #expect(world.motionComponents.entities.isEmpty)
        #expect(world.angularVelocityComponents.entities.isEmpty)
        #expect(world.angularMotionAccumulatorComponents.entities.isEmpty)

        #expect(world.positionComponents[Self.planetID]?.position == .zero)
        #expect(
            world.rotationComponents[Self.planetID]?.rotation.vector ==
                TerrestrialPlanet.standardRotation.vector
        )
        #expect(
            world.scaleComponents[Self.planetID]?.scale ==
                TerrestrialPlanet.standardScale
        )
        #expect(world.renderableComponents[Self.planetID]?.meshID == .terrestrialPlanet)
        #expect(world.renderableComponents[Self.planetID]?.materialID == .terrestrialPlanet)
        #expect(world.selectableComponents[Self.planetID]?.selectionState == .unselected)
    }

    @Test func remainsQuiescentAcrossFixedSteps() {
        let initialWorld = TerrestrialPlanetWorldBuilder().buildWorld()
        let sessionID = SimulationSessionID()
        let initialSnapshot = initialWorld.presentationSnapshot(
            at: SimulationCursor(sessionID: sessionID, tick: .zero)
        )
        let engine = Engine(
            world: initialWorld,
            fixedTimeStep: SimulationRuntime.fixedTimeStep,
            configuration: .basicGame
        )

        for _ in 0..<120 {
            engine.step()
        }

        let laterSnapshot = engine.world.presentationSnapshot(
            at: SimulationCursor(
                sessionID: sessionID,
                tick: engine.completedTick
            )
        )

        #expect(engine.completedTick == SimulationTick(rawValue: 120))
        #expect(laterSnapshot.entityPresentations == initialSnapshot.entityPresentations)
        #expect(engine.world.camera == TerrestrialPlanetWorldBuilder.proofCamera)
    }
}
