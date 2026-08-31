import Testing
@testable import Engine2

struct SMiningInteractionTests {
    @Test func heldInteractionMinesFiniteOreIntoAvailableCargo() {
        var world = World()
        let skiff = EntityID(index: 0, generation: 0)
        let asteroid = EntityID(index: 1, generation: 0)
        world.positionComponents.insert(CPosition(position: .zero), for: skiff)
        world.playerControlComponents.insert(CPlayerControl(interactionState: .active), for: skiff)
        world.cargoComponents.insert(CCargo(capacity: 8_000), for: skiff)
        world.positionComponents.insert(CPosition(position: SIMD3<Double>(100, 0, 0)), for: asteroid)
        world.oreDepositComponents.insert(COreDeposit(remainingOre: 4_000), for: asteroid)
        world.interactionComponents.insert(CInteraction(interactionRange: 140), for: asteroid)
        world.mineableComponents.insert(CMineable(miningRate: 800), for: asteroid)

        var system = SMiningInteraction()
        system.update(world: &world, deltaTime: 1)

        #expect(world.cargoComponents[skiff]?.ore == 800)
        #expect(world.oreDepositComponents[asteroid]?.remainingOre == 3_200)
    }

    @Test func depotUnloadsAndRefuelsDuringTheSameInterval() {
        var world = World()
        let skiff = EntityID(index: 0, generation: 0)
        let depot = EntityID(index: 1, generation: 0)
        world.positionComponents.insert(CPosition(position: .zero), for: skiff)
        world.playerControlComponents.insert(CPlayerControl(interactionState: .active), for: skiff)
        world.cargoComponents.insert(CCargo(capacity: 8_000, ore: 1_000), for: skiff)
        world.fuelComponents.insert(CFuel(capacity: 2_000, remaining: 1_000), for: skiff)
        world.positionComponents.insert(CPosition(position: SIMD3<Double>(100, 0, 0)), for: depot)
        world.interactionComponents.insert(CInteraction(interactionRange: 140), for: depot)
        world.depotServiceComponents.insert(
            CDepotService(unloadingRate: 1_600, refuelingRate: 400),
            for: depot
        )

        var system = SMiningInteraction()
        system.update(world: &world, deltaTime: 1)

        #expect(world.cargoComponents[skiff]?.ore == 0)
        #expect(world.fuelComponents[skiff]?.remaining == 1_400)
        #expect(world.depotServiceComponents[depot]?.deliveredOre == 1_000)
    }

    @Test func depotCanRefuelAnActorWithoutCargoStorage() {
        var world = World()
        let tug = EntityID(index: 0, generation: 0)
        let depot = EntityID(index: 1, generation: 0)
        world.positionComponents.insert(CPosition(position: .zero), for: tug)
        world.playerControlComponents.insert(CPlayerControl(interactionState: .active), for: tug)
        world.fuelComponents.insert(CFuel(capacity: 2_000, remaining: 1_000), for: tug)
        world.positionComponents.insert(CPosition(position: SIMD3<Double>(100, 0, 0)), for: depot)
        world.interactionComponents.insert(CInteraction(interactionRange: 140), for: depot)
        world.depotServiceComponents.insert(
            CDepotService(unloadingRate: 1_600, refuelingRate: 400),
            for: depot
        )

        var system = SMiningInteraction()
        system.update(world: &world, deltaTime: 1)

        #expect(world.fuelComponents[tug]?.remaining == 1_400)
        #expect(world.depotServiceComponents[depot]?.deliveredOre == 0)
    }

    @Test func depotCanUnloadAnActorWithoutFuelStorage() {
        var world = World()
        let hauler = EntityID(index: 0, generation: 0)
        let depot = EntityID(index: 1, generation: 0)
        world.positionComponents.insert(CPosition(position: .zero), for: hauler)
        world.playerControlComponents.insert(CPlayerControl(interactionState: .active), for: hauler)
        world.cargoComponents.insert(CCargo(capacity: 8_000, ore: 1_000), for: hauler)
        world.positionComponents.insert(CPosition(position: SIMD3<Double>(100, 0, 0)), for: depot)
        world.interactionComponents.insert(CInteraction(interactionRange: 140), for: depot)
        world.depotServiceComponents.insert(
            CDepotService(unloadingRate: 1_600, refuelingRate: 400),
            for: depot
        )

        var system = SMiningInteraction()
        system.update(world: &world, deltaTime: 1)

        #expect(world.cargoComponents[hauler]?.ore == 0)
        #expect(world.depotServiceComponents[depot]?.deliveredOre == 1_000)
    }
}
