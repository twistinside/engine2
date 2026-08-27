import Testing
@testable import Engine2

struct MiningWorldBuilderTests {
    @Test func buildsNineRegisteredBodiesWithTheSkiffSelected() {
        let world = MiningWorldBuilder().buildWorld()

        #expect(world.registeredEntities.count == 9)
        #expect(world.renderableComponents.dense.count == 9)
        #expect(world.gravitySourceComponents.dense.count == 1)
        #expect(world.gravityReceiverComponents.dense.count == 1)
        #expect(world.orbitalRailComponents.dense.count == 7)
        #expect(world.oreDepositComponents.dense.count == 6)
        #expect(world.depotServiceComponents.dense.count == 1)
        #expect(world.playerControlComponents.dense.count == 1)

        let selectedID = world.selectedEntityID
        #expect(selectedID != nil)
        #expect(selectedID == world.cameraFollowEntityID)
        #expect(selectedID.map { world.entity(for: $0) is MiningSkiff } == true)
        #expect(selectedID.flatMap { world.selectableComponents[$0]?.selectionState } == .selected)
    }

    @Test func registryUsesCompleteEntityIdentityAndLiveFacadeState() {
        let world = MiningWorldBuilder().buildWorld()
        let skiffID = world.playerControlComponents.entities[0]
        let skiff = world.entity(for: skiffID) as? MiningSkiff
        let staleID = EntityID(index: skiffID.index, generation: skiffID.generation + 1)

        #expect(skiff?.displayName == "Prospector")
        #expect(skiff?.mass == 12_000)
        #expect(world.entity(for: staleID) == nil)
    }

    @Test func cameraStartsObliqueToTheSkiffWithLongRangePerspective() {
        let world = MiningWorldBuilder().buildWorld()
        let skiffID = world.playerControlComponents.entities[0]
        let skiffPosition = world.positionComponents[skiffID]?.position

        #expect(world.camera.position.x == Float(skiffPosition?.x ?? .nan))
        #expect(
            world.camera.position.y
                == Float(skiffPosition?.y ?? .nan) - MiningWorldBuilder.cameraPlanarOffset
        )
        #expect(world.camera.position.z == 500)
        #expect(
            world.camera.projection == .perspective(
                verticalFieldOfView: .pi / 3,
                near: 1,
                far: 10_000
            )
        )
    }
}
