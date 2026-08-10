import Testing
import simd
@testable import Engine2

struct TerrestrialPlanetTests {
    @Test func initRegistersOneStaticLayeredPlanet() {
        let world = World()
        let expectedPosition = SIMD3<Float>(1, 2, 3)
        let expectedRotation = simd_quatf(
            angle: .pi / 6,
            axis: SIMD3<Float>(0, 1, 0)
        )
        let expectedScale = SIMD3<Float>(repeating: 3)
        let expectedSelectionState = CSelectable.SelectionState.highlighted

        let planet = TerrestrialPlanet(
            in: world,
            position: expectedPosition,
            rotation: expectedRotation,
            scale: expectedScale,
            selectionState: expectedSelectionState
        )

        #expect(planet.position == expectedPosition)
        #expect(planet.rotation.vector == expectedRotation.vector)
        #expect(planet.scale == expectedScale)
        #expect(planet.meshID == .terrestrialPlanet)
        #expect(planet.materialID == .terrestrialPlanet)
        #expect(planet.selectionState == expectedSelectionState)
        #expect(world.motionComponents[planet.id] == nil)
        #expect(world.angularVelocityComponents[planet.id] == nil)
        #expect(world.angularMotionAccumulatorComponents[planet.id] == nil)
    }

    @Test func initUsesTheStandardOrbitalProofTransform() {
        let world = World()
        let planet = TerrestrialPlanet(in: world)

        #expect(planet.position == .zero)
        #expect(planet.rotation.vector == TerrestrialPlanet.standardRotation.vector)
        #expect(planet.scale == SIMD3<Float>(repeating: 2.5))
        #expect(planet.scale == TerrestrialPlanet.standardScale)
        #expect(planet.selectionState == .unselected)
    }
}
