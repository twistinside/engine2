import Testing
@testable import Engine2

struct MiningWorldBuilderTests {
    @Test func buildsNineRegisteredBodiesWithTheSkiffSelected() {
        let world = MiningWorldBuilder().buildWorld()

        #expect(world.registeredEntities.count == 9)
        #expect(world.components[RenderableComponent.self].dense.count == 9)
        #expect(world.components[GravitySourceComponent.self].dense.count == 1)
        #expect(world.components[GravityReceiverComponent.self].dense.count == 1)
        #expect(world.components[OrbitalRailComponent.self].dense.count == 7)
        #expect(world.components[OreDepositComponent.self].dense.count == 6)
        #expect(world.components[DepotServiceComponent.self].dense.count == 1)
        #expect(world.components[PlayerControlComponent.self].dense.count == 1)
        #expect(world.components[MissileLauncherComponent.self].dense.count == 1)
        #expect(world.components[ContactConsumptionComponent.self].entities.isEmpty)
        #expect(world.components[OrbitPrimaryComponent.self].dense.count == 1)

        let selectedID = world.selectedEntityID
        #expect(selectedID != nil)
        #expect(selectedID == world.cameraFollowEntityID)
        #expect(selectedID.map { world.entity(for: $0) is MiningSkiff } == true)
        #expect(selectedID.flatMap { world.components[SelectableComponent.self][$0]?.selectionState } == .selected)
    }

    @Test func registryUsesCompleteEntityIdentityAndLiveFacadeState() {
        let world = MiningWorldBuilder().buildWorld()
        let skiffID = world.components[PlayerControlComponent.self].entities[0]
        let skiff = world.entity(for: skiffID) as? MiningSkiff
        let staleID = EntityID(index: skiffID.index, generation: skiffID.generation + 1)

        #expect(skiff?.displayName == "Prospector")
        #expect(skiff?.mass == 12_000)
        #expect(skiff?.orbitCircularizationEstimate != nil)
        #expect(world.entity(for: staleID) == nil)
    }

    @Test func cameraStartsMoreTopDownFromTheSkiffWithLongRangePerspective() {
        let world = MiningWorldBuilder().buildWorld()
        let skiffID = world.components[PlayerControlComponent.self].entities[0]
        let skiffPosition = world.components[PositionComponent.self][skiffID]?.position

        #expect(
            MiningWorldBuilder.cameraHeight
                > 2 * MiningWorldBuilder.cameraPlanarOffset
        )
        #expect(world.camera.position.x == Float(skiffPosition?.x ?? .nan))
        #expect(
            world.camera.position.y
                == Float(skiffPosition?.y ?? .nan) - MiningWorldBuilder.cameraPlanarOffset
        )
        #expect(world.camera.position.z == MiningWorldBuilder.cameraHeight)
        #expect(
            world.camera.projection == .perspective(
                verticalFieldOfView: .pi / 3,
                near: 1,
                far: 20_000
            )
        )
    }

    @Test func authorsExpandedCircularRailsAndDesignatesTheSkiffPrimary() throws {
        let world = MiningWorldBuilder().buildWorld()
        let starID = try #require(world.components[GravitySourceComponent.self].entities.first)
        let skiffID = try #require(world.components[PlayerControlComponent.self].entities.first)
        let asteroidRadii = world.registeredEntities.compactMap { entity in
            (entity as? Asteroid)?.orbitalRadius
        }.sorted()
        let depotRadius = world.registeredEntities.compactMap { entity in
            (entity as? MiningDepot)?.orbitalRadius
        }.first

        #expect(
            world.components[GravitySourceComponent.self][starID]?.gravitationalParameter
                == MiningWorldBuilder.gravitationalParameter
        )
        #expect(world.components[OrbitPrimaryComponent.self][skiffID]?.primaryEntityID == starID)
        #expect(asteroidRadii == [1_800, 2_400, 3_000, 3_600, 4_300, 5_000])
        #expect(depotRadius == MiningWorldBuilder.depotOrbitRadius)

        for rail in world.components[OrbitalRailComponent.self].dense {
            let expectedAngularSpeed = sqrt(
                MiningWorldBuilder.gravitationalParameter
                    / (rail.radius * rail.radius * rail.radius)
            )
            #expect(abs(rail.angularSpeed - expectedAngularSpeed) < 1e-15)
        }
    }
}
