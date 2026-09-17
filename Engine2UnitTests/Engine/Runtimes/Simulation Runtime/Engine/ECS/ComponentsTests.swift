import Testing
@testable import Engine2

struct ComponentsTests {
    @Test func everyRegisteredTypeHasAnEmptyStoreBeforeSpawning() {
        let components = Components()
        #expect(Components.types.count == 33)
        #expect(Set(Components.types.map { ObjectIdentifier($0) }).count == Components.types.count)
        for type in Components.types {
            expectEmpty(type, in: components)
        }
    }

    @Test func retainedTypedStoreStaysLiveAndWorldsRemainIndependent() {
        let first = World()
        let second = World()
        let entity = Entity(in: first, from: .empty)
        let positions = first.components[PositionComponent.self]
        #expect(positions === first.components[PositionComponent.self])
        #expect(positions !== second.components[PositionComponent.self])
        positions.insert(PositionComponent(position: .zero), for: entity.id)
        first.components[MotionComponent.self].insert(MotionComponent(), for: entity.id)

        let didUpdate = positions.update(for: entity.id) { position in
            first.components[MotionComponent.self].update(for: entity.id) { motion in
                motion.velocity = SIMD3<Double>(1, 2, 3)
                position.position = motion.velocity
            }
        }
        #expect(didUpdate)
        #expect(first.components[PositionComponent.self][entity.id]?.position == SIMD3<Double>(1, 2, 3))
        #expect(first.components[MotionComponent.self][entity.id]?.velocity == SIMD3<Double>(1, 2, 3))
        #expect(second.components[PositionComponent.self][entity.id] == nil)

        positions.remove(for: entity.id)
        #expect(first.components[PositionComponent.self][entity.id] == nil)
        #expect(first.components[MotionComponent.self][entity.id]?.velocity == SIMD3<Double>(1, 2, 3))
        #expect(second.components[PositionComponent.self].dense.isEmpty)
    }

    @Test func bareEntityGetsOnlyItsInheritedLifecycleComponent() {
        let world = World()
        let entity = Entity(in: world, from: .empty)
        for type in Components.types where ObjectIdentifier(type) != ObjectIdentifier(DestructibleComponent.self) {
            expectEmpty(type, in: world.components)
        }
        #expect(world.components[DestructibleComponent.self][entity.id]?.state == .active)
    }

    @Test func renderableInitializerUsesAuthoredValuesBeforeAnyRowsExist() throws {
        let world = World()
        let entity = InitialStateRailEntity(unregisteredID: world.reserveEntityID(), in: world)
        let component = try #require(RenderableComponent(
            for: entity,
            from: Entity.InitialState(meshID: .ball, materialID: .goldMetal)
        ))
        #expect(component.meshID == .ball)
        #expect(component.materialID == .goldMetal)
        for type in Components.types {
            expectEmpty(type, in: world.components)
        }
    }

    @Test func protocolDefaultRemovalPreservesOtherRowsAndRejectsStaleIdentities() {
        let world = MiningWorldBuilder().buildWorld()
        for type in Components.types {
            checkDefaultRemoval(type, in: world.components)
        }
    }

    @Test func destroyingTheMiningSceneClearsEveryRegisteredStore() {
        let world = MiningWorldBuilder().buildWorld()
        let entities = world.registeredEntities.map(\.id)
        for entity in entities {
            #expect(world.destroy(entity))
        }
        #expect(world.registeredEntities.isEmpty)
        #expect(world.selectedEntityID == nil)
        #expect(world.cameraFollowEntityID == nil)
        for type in Components.types {
            expectEmpty(type, in: world.components)
        }
    }

    private func expectEmpty<C: Component>(_ type: C.Type, in components: Components) {
        #expect(components[type].dense.isEmpty)
        #expect(components[type].entities.isEmpty)
        #expect(components[type].sparse.isEmpty)
    }

    private func checkDefaultRemoval<C: Component>(_ type: C.Type, in components: Components) {
        let entities = components[type].entities
        let dense = components[type].dense
        guard let entity = entities.first else { return }
        let erasedType: any Component.Type = type
        erasedType.remove(for: EntityID(index: entity.index, generation: entity.generation + 1), from: components)
        #expect(components[type].entities == entities)
        #expect(components[type].dense == dense)

        erasedType.remove(for: entity, from: components)
        erasedType.remove(for: entity, from: components)
        #expect(components[type][entity] == nil)
        #expect(components[type].dense.count == dense.count - 1)
        for (survivor, component) in zip(entities, dense) where survivor != entity {
            #expect(components[type][survivor] == component)
        }
    }
}
