import Testing
@testable import Engine2

struct MiningInteractionSystemTests {
    @Test func pendingRemovalActorCannotMine() {
        var world = World()
        let actor = EntityID(index: 0, generation: 0)
        let asteroid = EntityID(index: 1, generation: 0)
        world.positionComponents.insert(PositionComponent(position: .zero), for: actor)
        world.playerControlComponents.insert(
            PlayerControlComponent(interactionState: .active, isFireRequested: false),
            for: actor
        )
        world.cargoComponents.insert(CargoComponent(capacity: 8_000), for: actor)
        world.positionComponents.insert(PositionComponent(position: SIMD3<Double>(10, 0, 0)), for: asteroid)
        world.oreDepositComponents.insert(OreDepositComponent(remainingOre: 4_000), for: asteroid)
        world.interactionComponents.insert(InteractionComponent(interactionRange: 140), for: asteroid)
        world.mineableComponents.insert(MineableComponent(miningRate: 800), for: asteroid)
        world.pendingRemovalComponents.insert(PendingRemovalComponent(), for: actor)

        var system = MiningInteractionSystem()
        system.update(world: &world, deltaTime: 1)

        #expect(world.cargoComponents[actor]?.ore == 0)
        #expect(world.oreDepositComponents[asteroid]?.remainingOre == 4_000)
        #expect(world.playerControlComponents[actor]?.interactionState == .active)
        #expect(world.pendingRemovalComponents[actor] != nil)
    }

    @Test func pendingRemovalAsteroidDoesNotBlockMiningASurvivingTarget() {
        var world = World()
        let actor = EntityID(index: 0, generation: 0)
        let pending = EntityID(index: 1, generation: 0)
        let surviving = EntityID(index: 2, generation: 0)
        world.positionComponents.insert(PositionComponent(position: .zero), for: actor)
        world.playerControlComponents.insert(
            PlayerControlComponent(interactionState: .active, isFireRequested: false),
            for: actor
        )
        world.cargoComponents.insert(CargoComponent(capacity: 8_000), for: actor)
        for (asteroid, position) in [(pending, SIMD3<Double>(10, 0, 0)), (surviving, SIMD3<Double>(20, 0, 0))] {
            world.positionComponents.insert(PositionComponent(position: position), for: asteroid)
            world.oreDepositComponents.insert(OreDepositComponent(remainingOre: 4_000), for: asteroid)
            world.interactionComponents.insert(InteractionComponent(interactionRange: 140), for: asteroid)
            world.mineableComponents.insert(MineableComponent(miningRate: 800), for: asteroid)
        }
        world.pendingRemovalComponents.insert(PendingRemovalComponent(), for: pending)

        var system = MiningInteractionSystem()
        system.update(world: &world, deltaTime: 1)

        #expect(world.cargoComponents[actor]?.ore == 800)
        #expect(world.oreDepositComponents[pending]?.remainingOre == 4_000)
        #expect(world.oreDepositComponents[surviving]?.remainingOre == 3_200)
        #expect(world.pendingRemovalComponents[pending] != nil)
    }

    @Test func pendingRemovalDepotDoesNotBlockServiceAtASurvivingDepot() {
        var world = World()
        let actor = EntityID(index: 0, generation: 0)
        let pending = EntityID(index: 1, generation: 0)
        let surviving = EntityID(index: 2, generation: 0)
        world.positionComponents.insert(PositionComponent(position: .zero), for: actor)
        world.playerControlComponents.insert(
            PlayerControlComponent(interactionState: .active, isFireRequested: false),
            for: actor
        )
        world.cargoComponents.insert(CargoComponent(capacity: 8_000, ore: 1_000), for: actor)
        world.fuelComponents.insert(FuelComponent(capacity: 2_000, remaining: 1_000), for: actor)
        for (depot, position) in [(pending, SIMD3<Double>(10, 0, 0)), (surviving, SIMD3<Double>(20, 0, 0))] {
            world.positionComponents.insert(PositionComponent(position: position), for: depot)
            world.interactionComponents.insert(InteractionComponent(interactionRange: 140), for: depot)
            world.depotServiceComponents.insert(
                DepotServiceComponent(unloadingRate: 1_600, refuelingRate: 400),
                for: depot
            )
        }
        world.pendingRemovalComponents.insert(PendingRemovalComponent(), for: pending)

        var system = MiningInteractionSystem()
        system.update(world: &world, deltaTime: 1)

        #expect(world.cargoComponents[actor]?.ore == 0)
        #expect(world.fuelComponents[actor]?.remaining == 1_400)
        #expect(world.depotServiceComponents[pending]?.deliveredOre == 0)
        #expect(world.depotServiceComponents[surviving]?.deliveredOre == 1_000)
        #expect(world.pendingRemovalComponents[pending] != nil)
    }

    @Test func heldInteractionMinesFiniteOreIntoAvailableCargo() {
        var world = World()
        let skiff = EntityID(index: 0, generation: 0)
        let asteroid = EntityID(index: 1, generation: 0)
        world.positionComponents.insert(PositionComponent(position: .zero), for: skiff)
        world.playerControlComponents.insert(
            PlayerControlComponent(interactionState: .active, isFireRequested: false),
            for: skiff
        )
        world.cargoComponents.insert(CargoComponent(capacity: 8_000), for: skiff)
        world.positionComponents.insert(PositionComponent(position: SIMD3<Double>(100, 0, 0)), for: asteroid)
        world.oreDepositComponents.insert(OreDepositComponent(remainingOre: 4_000), for: asteroid)
        world.interactionComponents.insert(InteractionComponent(interactionRange: 140), for: asteroid)
        world.mineableComponents.insert(MineableComponent(miningRate: 800), for: asteroid)

        var system = MiningInteractionSystem()
        system.update(world: &world, deltaTime: 1)

        #expect(world.cargoComponents[skiff]?.ore == 800)
        #expect(world.oreDepositComponents[asteroid]?.remainingOre == 3_200)
    }

    @Test func depotUnloadsAndRefuelsDuringTheSameInterval() {
        var world = World()
        let skiff = EntityID(index: 0, generation: 0)
        let depot = EntityID(index: 1, generation: 0)
        world.positionComponents.insert(PositionComponent(position: .zero), for: skiff)
        world.playerControlComponents.insert(
            PlayerControlComponent(interactionState: .active, isFireRequested: false),
            for: skiff
        )
        world.cargoComponents.insert(CargoComponent(capacity: 8_000, ore: 1_000), for: skiff)
        world.fuelComponents.insert(FuelComponent(capacity: 2_000, remaining: 1_000), for: skiff)
        world.positionComponents.insert(PositionComponent(position: SIMD3<Double>(100, 0, 0)), for: depot)
        world.interactionComponents.insert(InteractionComponent(interactionRange: 140), for: depot)
        world.depotServiceComponents.insert(
            DepotServiceComponent(unloadingRate: 1_600, refuelingRate: 400),
            for: depot
        )

        var system = MiningInteractionSystem()
        system.update(world: &world, deltaTime: 1)

        #expect(world.cargoComponents[skiff]?.ore == 0)
        #expect(world.fuelComponents[skiff]?.remaining == 1_400)
        #expect(world.depotServiceComponents[depot]?.deliveredOre == 1_000)
    }

    @Test func depotCanRefuelAnActorWithoutCargoStorage() {
        var world = World()
        let tug = EntityID(index: 0, generation: 0)
        let depot = EntityID(index: 1, generation: 0)
        world.positionComponents.insert(PositionComponent(position: .zero), for: tug)
        world.playerControlComponents.insert(
            PlayerControlComponent(interactionState: .active, isFireRequested: false),
            for: tug
        )
        world.fuelComponents.insert(FuelComponent(capacity: 2_000, remaining: 1_000), for: tug)
        world.positionComponents.insert(PositionComponent(position: SIMD3<Double>(100, 0, 0)), for: depot)
        world.interactionComponents.insert(InteractionComponent(interactionRange: 140), for: depot)
        world.depotServiceComponents.insert(
            DepotServiceComponent(unloadingRate: 1_600, refuelingRate: 400),
            for: depot
        )

        var system = MiningInteractionSystem()
        system.update(world: &world, deltaTime: 1)

        #expect(world.fuelComponents[tug]?.remaining == 1_400)
        #expect(world.depotServiceComponents[depot]?.deliveredOre == 0)
    }

    @Test func depotCanUnloadAnActorWithoutFuelStorage() {
        var world = World()
        let hauler = EntityID(index: 0, generation: 0)
        let depot = EntityID(index: 1, generation: 0)
        world.positionComponents.insert(PositionComponent(position: .zero), for: hauler)
        world.playerControlComponents.insert(
            PlayerControlComponent(interactionState: .active, isFireRequested: false),
            for: hauler
        )
        world.cargoComponents.insert(CargoComponent(capacity: 8_000, ore: 1_000), for: hauler)
        world.positionComponents.insert(PositionComponent(position: SIMD3<Double>(100, 0, 0)), for: depot)
        world.interactionComponents.insert(InteractionComponent(interactionRange: 140), for: depot)
        world.depotServiceComponents.insert(
            DepotServiceComponent(unloadingRate: 1_600, refuelingRate: 400),
            for: depot
        )

        var system = MiningInteractionSystem()
        system.update(world: &world, deltaTime: 1)

        #expect(world.cargoComponents[hauler]?.ore == 0)
        #expect(world.depotServiceComponents[depot]?.deliveredOre == 1_000)
    }
}
