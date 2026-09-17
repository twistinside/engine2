import Testing
@testable import Engine2

struct MiningInteractionSystemTests {
    @Test func pendingRemovalActorCannotMine() {
        var world = World()
        let actor = Entity(in: world, from: .empty).id
        let asteroid = Entity(in: world, from: .empty).id
        world.components[PositionComponent.self].insert(PositionComponent(position: .zero), for: actor)
        world.components[PlayerControlComponent.self].insert(
            PlayerControlComponent(interactionState: .active, isFireRequested: false),
            for: actor
        )
        world.components[CargoComponent.self].insert(CargoComponent(capacity: 8_000), for: actor)
        world.components[PositionComponent.self].insert(PositionComponent(position: SIMD3<Double>(10, 0, 0)), for: asteroid)
        world.components[OreDepositComponent.self].insert(OreDepositComponent(remainingOre: 4_000), for: asteroid)
        world.components[InteractionComponent.self].insert(InteractionComponent(interactionRange: 140), for: asteroid)
        world.components[MineableComponent.self].insert(MineableComponent(miningRate: 800), for: asteroid)
        #expect(world.components[DestructibleComponent.self].update(for: actor) { $0.state = .pendingRemoval })

        var system = MiningInteractionSystem()
        system.update(world: &world, deltaTime: 1)

        #expect(world.components[CargoComponent.self][actor]?.ore == 0)
        #expect(world.components[OreDepositComponent.self][asteroid]?.remainingOre == 4_000)
        #expect(world.components[PlayerControlComponent.self][actor]?.interactionState == .active)
        #expect(world.entity(for: actor)?.lifecycleState == .pendingRemoval)
    }

    @Test func pendingRemovalAsteroidDoesNotBlockMiningASurvivingTarget() {
        var world = World()
        let actor = Entity(in: world, from: .empty).id
        let pending = Entity(in: world, from: .empty).id
        let surviving = Entity(in: world, from: .empty).id
        world.components[PositionComponent.self].insert(PositionComponent(position: .zero), for: actor)
        world.components[PlayerControlComponent.self].insert(
            PlayerControlComponent(interactionState: .active, isFireRequested: false),
            for: actor
        )
        world.components[CargoComponent.self].insert(CargoComponent(capacity: 8_000), for: actor)
        for (asteroid, position) in [(pending, SIMD3<Double>(10, 0, 0)), (surviving, SIMD3<Double>(20, 0, 0))] {
            world.components[PositionComponent.self].insert(PositionComponent(position: position), for: asteroid)
            world.components[OreDepositComponent.self].insert(OreDepositComponent(remainingOre: 4_000), for: asteroid)
            world.components[InteractionComponent.self].insert(InteractionComponent(interactionRange: 140), for: asteroid)
            world.components[MineableComponent.self].insert(MineableComponent(miningRate: 800), for: asteroid)
        }
        #expect(world.components[DestructibleComponent.self].update(for: pending) { $0.state = .pendingRemoval })

        var system = MiningInteractionSystem()
        system.update(world: &world, deltaTime: 1)

        #expect(world.components[CargoComponent.self][actor]?.ore == 800)
        #expect(world.components[OreDepositComponent.self][pending]?.remainingOre == 4_000)
        #expect(world.components[OreDepositComponent.self][surviving]?.remainingOre == 3_200)
        #expect(world.entity(for: pending)?.lifecycleState == .pendingRemoval)
    }

    @Test func pendingRemovalDepotDoesNotBlockServiceAtASurvivingDepot() {
        var world = World()
        let actor = Entity(in: world, from: .empty).id
        let pending = Entity(in: world, from: .empty).id
        let surviving = Entity(in: world, from: .empty).id
        world.components[PositionComponent.self].insert(PositionComponent(position: .zero), for: actor)
        world.components[PlayerControlComponent.self].insert(
            PlayerControlComponent(interactionState: .active, isFireRequested: false),
            for: actor
        )
        world.components[CargoComponent.self].insert(CargoComponent(capacity: 8_000, ore: 1_000), for: actor)
        world.components[FuelComponent.self].insert(FuelComponent(capacity: 2_000, remaining: 1_000), for: actor)
        for (depot, position) in [(pending, SIMD3<Double>(10, 0, 0)), (surviving, SIMD3<Double>(20, 0, 0))] {
            world.components[PositionComponent.self].insert(PositionComponent(position: position), for: depot)
            world.components[InteractionComponent.self].insert(InteractionComponent(interactionRange: 140), for: depot)
            world.components[DepotServiceComponent.self].insert(
                DepotServiceComponent(unloadingRate: 1_600, refuelingRate: 400),
                for: depot
            )
        }
        #expect(world.components[DestructibleComponent.self].update(for: pending) { $0.state = .pendingRemoval })

        var system = MiningInteractionSystem()
        system.update(world: &world, deltaTime: 1)

        #expect(world.components[CargoComponent.self][actor]?.ore == 0)
        #expect(world.components[FuelComponent.self][actor]?.remaining == 1_400)
        #expect(world.components[DepotServiceComponent.self][pending]?.deliveredOre == 0)
        #expect(world.components[DepotServiceComponent.self][surviving]?.deliveredOre == 1_000)
        #expect(world.entity(for: pending)?.lifecycleState == .pendingRemoval)
    }

    @Test func heldInteractionMinesFiniteOreIntoAvailableCargo() {
        var world = World()
        let skiff = Entity(in: world, from: .empty).id
        let asteroid = Entity(in: world, from: .empty).id
        world.components[PositionComponent.self].insert(PositionComponent(position: .zero), for: skiff)
        world.components[PlayerControlComponent.self].insert(
            PlayerControlComponent(interactionState: .active, isFireRequested: false),
            for: skiff
        )
        world.components[CargoComponent.self].insert(CargoComponent(capacity: 8_000), for: skiff)
        world.components[PositionComponent.self].insert(PositionComponent(position: SIMD3<Double>(100, 0, 0)), for: asteroid)
        world.components[OreDepositComponent.self].insert(OreDepositComponent(remainingOre: 4_000), for: asteroid)
        world.components[InteractionComponent.self].insert(InteractionComponent(interactionRange: 140), for: asteroid)
        world.components[MineableComponent.self].insert(MineableComponent(miningRate: 800), for: asteroid)

        var system = MiningInteractionSystem()
        system.update(world: &world, deltaTime: 1)

        #expect(world.components[CargoComponent.self][skiff]?.ore == 800)
        #expect(world.components[OreDepositComponent.self][asteroid]?.remainingOre == 3_200)
    }

    @Test func depotUnloadsAndRefuelsDuringTheSameInterval() {
        var world = World()
        let skiff = Entity(in: world, from: .empty).id
        let depot = Entity(in: world, from: .empty).id
        world.components[PositionComponent.self].insert(PositionComponent(position: .zero), for: skiff)
        world.components[PlayerControlComponent.self].insert(
            PlayerControlComponent(interactionState: .active, isFireRequested: false),
            for: skiff
        )
        world.components[CargoComponent.self].insert(CargoComponent(capacity: 8_000, ore: 1_000), for: skiff)
        world.components[FuelComponent.self].insert(FuelComponent(capacity: 2_000, remaining: 1_000), for: skiff)
        world.components[PositionComponent.self].insert(PositionComponent(position: SIMD3<Double>(100, 0, 0)), for: depot)
        world.components[InteractionComponent.self].insert(InteractionComponent(interactionRange: 140), for: depot)
        world.components[DepotServiceComponent.self].insert(
            DepotServiceComponent(unloadingRate: 1_600, refuelingRate: 400),
            for: depot
        )

        var system = MiningInteractionSystem()
        system.update(world: &world, deltaTime: 1)

        #expect(world.components[CargoComponent.self][skiff]?.ore == 0)
        #expect(world.components[FuelComponent.self][skiff]?.remaining == 1_400)
        #expect(world.components[DepotServiceComponent.self][depot]?.deliveredOre == 1_000)
    }

    @Test func depotCanRefuelAnActorWithoutCargoStorage() {
        var world = World()
        let tug = Entity(in: world, from: .empty).id
        let depot = Entity(in: world, from: .empty).id
        world.components[PositionComponent.self].insert(PositionComponent(position: .zero), for: tug)
        world.components[PlayerControlComponent.self].insert(
            PlayerControlComponent(interactionState: .active, isFireRequested: false),
            for: tug
        )
        world.components[FuelComponent.self].insert(FuelComponent(capacity: 2_000, remaining: 1_000), for: tug)
        world.components[PositionComponent.self].insert(PositionComponent(position: SIMD3<Double>(100, 0, 0)), for: depot)
        world.components[InteractionComponent.self].insert(InteractionComponent(interactionRange: 140), for: depot)
        world.components[DepotServiceComponent.self].insert(
            DepotServiceComponent(unloadingRate: 1_600, refuelingRate: 400),
            for: depot
        )

        var system = MiningInteractionSystem()
        system.update(world: &world, deltaTime: 1)

        #expect(world.components[FuelComponent.self][tug]?.remaining == 1_400)
        #expect(world.components[DepotServiceComponent.self][depot]?.deliveredOre == 0)
    }

    @Test func depotCanUnloadAnActorWithoutFuelStorage() {
        var world = World()
        let hauler = Entity(in: world, from: .empty).id
        let depot = Entity(in: world, from: .empty).id
        world.components[PositionComponent.self].insert(PositionComponent(position: .zero), for: hauler)
        world.components[PlayerControlComponent.self].insert(
            PlayerControlComponent(interactionState: .active, isFireRequested: false),
            for: hauler
        )
        world.components[CargoComponent.self].insert(CargoComponent(capacity: 8_000, ore: 1_000), for: hauler)
        world.components[PositionComponent.self].insert(PositionComponent(position: SIMD3<Double>(100, 0, 0)), for: depot)
        world.components[InteractionComponent.self].insert(InteractionComponent(interactionRange: 140), for: depot)
        world.components[DepotServiceComponent.self].insert(
            DepotServiceComponent(unloadingRate: 1_600, refuelingRate: 400),
            for: depot
        )

        var system = MiningInteractionSystem()
        system.update(world: &world, deltaTime: 1)

        #expect(world.components[CargoComponent.self][hauler]?.ore == 0)
        #expect(world.components[DepotServiceComponent.self][depot]?.deliveredOre == 1_000)
    }
}
