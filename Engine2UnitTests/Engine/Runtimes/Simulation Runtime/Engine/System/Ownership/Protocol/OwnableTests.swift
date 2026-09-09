import Testing
@testable import Engine2

struct OwnableTests {
    @Test func ownershipOnlyFacadeTracksTransfersAndRetainsADestroyedOwnersIdentity() {
        let world = World()
        let firstOwner = Entity(in: world, from: .empty)
        let nextOwner = Entity(in: world, from: .empty)
        let entity = OwnershipTestEntity(
            in: world,
            from: Entity.InitialState(ownership: OwnershipComponent(ownerEntityID: firstOwner.id))
        )
        #expect(entity.ownerEntityID == firstOwner.id)
        #expect(world.positionComponents[entity.id] == nil)
        #expect(world.motionComponents[entity.id] == nil)
        #expect(world.collisionBodyComponents[entity.id] == nil)
        #expect(world.lifetimeComponents[entity.id] == nil)
        #expect(world.fireableComponents[entity.id] == nil)

        world.ownershipComponents.update(for: entity.id) { ownership in
            ownership.ownerEntityID = nextOwner.id
        }
        #expect(entity.ownerEntityID == nextOwner.id)

        world.destroy(nextOwner.id)

        #expect(world.entity(for: nextOwner.id) == nil)
        #expect(world.entity(for: entity.id) === entity)
        #expect(entity.ownerEntityID == nextOwner.id)
    }

    @Test func ownershipPreservesAnIdentityWithoutRequiringALiveOwner() {
        let world = World()
        let ownerID = EntityID(index: 77, generation: 9)
        let entity = OwnershipTestEntity(
            in: world,
            from: Entity.InitialState(ownership: OwnershipComponent(ownerEntityID: ownerID))
        )

        #expect(world.entity(for: ownerID) == nil)
        #expect(entity.ownerEntityID == ownerID)
    }
}
