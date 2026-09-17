import Testing
@testable import Engine2

struct ComponentStoreTests {
    @Test func insertAppendsAlignedDenseAndSparseStorage() {
        let store = ComponentStore<PositionComponent>()
        let mutations: any ComponentStoring<PositionComponent> = store
        let first = EntityID(index: 4, generation: 0)
        let second = EntityID(index: 9, generation: 2)
        let firstPositionValue = SIMD3<Double>(1, 2, 3)
        let secondPositionValue = SIMD3<Double>(4, 5, 6)
        let firstPosition = PositionComponent(position: firstPositionValue)
        let secondPosition = PositionComponent(position: secondPositionValue)

        mutations.insert(firstPosition, for: first)
        mutations.insert(secondPosition, for: second)

        let expectedPositions = [firstPositionValue, secondPositionValue]

        #expect(store.dense.map(\.position) == expectedPositions)
        #expect(store.entities == [first, second])
        #expect(store.sparse == [4: 0, 9: 1])
        #expect(store[first]?.position == firstPositionValue)
        #expect(store[second]?.position == secondPositionValue)
    }

    @Test func insertForExistingEntityReplacesWithoutAppending() {
        let store = ComponentStore<PositionComponent>()
        let mutations: any ComponentStoring<PositionComponent> = store
        let entity = EntityID(index: 3, generation: 1)
        let replacementPositionValue = SIMD3<Double>(7, 8, 9)
        let initialPosition = PositionComponent(position: SIMD3<Double>(1, 2, 3))
        let replacementPosition = PositionComponent(position: replacementPositionValue)

        mutations.insert(initialPosition, for: entity)
        mutations.insert(replacementPosition, for: entity)

        #expect(store.dense.count == 1)
        #expect(store.entities == [entity])
        #expect(store.sparse == [3: 0])
        #expect(store[entity]?.position == replacementPositionValue)
    }

    @Test func updateMutatesExistingDenseRowAndReportsSuccess() {
        let store = ComponentStore<PositionComponent>()
        let mutations: any ComponentStoring<PositionComponent> = store
        let entity = EntityID(index: 1, generation: 0)
        let position = PositionComponent(position: .zero)
        mutations.insert(position, for: entity)

        let expectedPosition = SIMD3<Double>(3, 4, 5)
        let didUpdate = mutations.update(for: entity) { position in
            position.position = expectedPosition
        }

        #expect(didUpdate)
        #expect(store[entity]?.position == expectedPosition)
    }

    @Test func fullEntityIdentityProtectsLookupAndUpdateFromStaleGeneration() {
        let store = ComponentStore<PositionComponent>()
        let liveEntity = EntityID(index: 7, generation: 3)
        let staleEntity = EntityID(index: 7, generation: 2)
        let livePositionValue = SIMD3<Double>(1, 2, 3)
        let livePosition = PositionComponent(position: livePositionValue)
        store.insert(livePosition, for: liveEntity)

        let didUpdate = store.update(for: staleEntity) { position in
            position.position = SIMD3<Double>(9, 9, 9)
        }

        #expect(store[staleEntity] == nil)
        #expect(didUpdate == false)
        #expect(store[liveEntity]?.position == livePositionValue)
    }

    @Test func updateReportsFailureForMissingEntity() {
        let store = ComponentStore<PositionComponent>()
        let missingEntity = EntityID(index: 42, generation: 0)

        let didUpdate = store.update(
            for: missingEntity
        ) { position in
            position.position = SIMD3<Double>(1, 1, 1)
        }

        #expect(didUpdate == false)
        #expect(store.dense.isEmpty)
    }

    @Test func largeSparseIndexDoesNotAllocateDensePadding() {
        let store = ComponentStore<PositionComponent>()
        let entity = EntityID(index: Int.max, generation: 0)
        let positionValue = SIMD3<Double>(1, 2, 3)
        let position = PositionComponent(position: positionValue)

        store.insert(position, for: entity)

        #expect(store.dense.count == 1)
        #expect(store.entities == [entity])
        #expect(store.sparse == [Int.max: 0])
        #expect(store[entity]?.position == positionValue)
    }

    @Test func failedUpdateNeverExecutesMutationBody() {
        let store = ComponentStore<PositionComponent>()
        let live = EntityID(index: 3, generation: 2)
        let stale = EntityID(index: 3, generation: 1)
        let position = PositionComponent(position: .zero)
        store.insert(position, for: live)
        var invocationCount = 0

        let didUpdate = store.update(for: stale) { _ in
            invocationCount += 1
        }

        #expect(didUpdate == false)
        #expect(invocationCount == 0)
    }

    @Test func removeCompactsTheMiddleRowAndRepairsMovedLookup() {
        let store = ComponentStore<PositionComponent>()
        let first = EntityID(index: 4, generation: 2)
        let removed = EntityID(index: 8, generation: 3)
        let moved = EntityID(index: 12, generation: 4)
        store.insert(PositionComponent(position: SIMD3<Double>(1, 0, 0)), for: first)
        store.insert(PositionComponent(position: SIMD3<Double>(2, 0, 0)), for: removed)
        store.insert(PositionComponent(position: SIMD3<Double>(3, 0, 0)), for: moved)

        let didRemove = store.remove(for: removed)

        #expect(didRemove)

        #expect(store.entities == [first, moved])
        #expect(store.sparse == [first.index: 0, moved.index: 1])
        #expect(store[removed] == nil)
        #expect(store[first]?.position == SIMD3<Double>(1, 0, 0))
        #expect(store[moved]?.position == SIMD3<Double>(3, 0, 0))
        let didUpdate = store.update(for: moved) { $0.position.y = 7 }
        #expect(didUpdate)
        #expect(store.dense[1].position == SIMD3<Double>(3, 7, 0))
    }

    @Test func removeRejectsStaleAndMissingIdentitiesWithoutChangingLiveRows() {
        let store = ComponentStore<PositionComponent>()
        let live = EntityID(index: 3, generation: 2)
        let stale = EntityID(index: 3, generation: 1)
        store.insert(PositionComponent(position: SIMD3<Double>(1, 2, 3)), for: live)

        let didRemoveStale = store.remove(for: stale)
        let didRemoveMissing = store.remove(for: EntityID(index: 99, generation: 0))

        #expect(didRemoveStale == false)
        #expect(didRemoveMissing == false)

        #expect(store.entities == [live])
        #expect(store.sparse == [live.index: 0])
        #expect(store[live]?.position == SIMD3<Double>(1, 2, 3))
    }

    @Test func removeLastRowAndRepeatedRemovalLeaveEmptyStorage() {
        let store = ComponentStore<PositionComponent>()
        let entity = EntityID(index: 3, generation: 2)
        store.insert(PositionComponent(position: .zero), for: entity)

        let didRemove = store.remove(for: entity)
        let didRemoveAgain = store.remove(for: entity)

        #expect(didRemove)
        #expect(didRemoveAgain == false)
        #expect(store.dense.isEmpty)
        #expect(store.entities.isEmpty)
        #expect(store.sparse.isEmpty)
    }

    @Test func laterGenerationCanOccupyAnExplicitlyRemovedIndex() {
        let store = ComponentStore<PositionComponent>()
        let old = EntityID(index: 3, generation: 2)
        let replacement = EntityID(index: 3, generation: 3)
        store.insert(PositionComponent(position: .zero), for: old)
        store.remove(for: old)

        store.insert(PositionComponent(position: SIMD3<Double>(4, 5, 6)), for: replacement)

        let didRemoveOld = store.remove(for: old)

        #expect(didRemoveOld == false)
        #expect(store[old] == nil)
        #expect(store.entities == [replacement])
        #expect(store[replacement]?.position == SIMD3<Double>(4, 5, 6))
    }

    @Test func retainedStoreReferenceObservesUpdatesAndRemoval() {
        let store = ComponentStore<PositionComponent>()
        let entity = EntityID(index: 3, generation: 2)
        store.insert(PositionComponent(position: .zero), for: entity)
        let retained = store

        #expect(retained === store)
        retained.update(for: entity) { $0.position = SIMD3<Double>(9, 8, 7) }
        #expect(store[entity]?.position == SIMD3<Double>(9, 8, 7))

        store.remove(for: entity)

        #expect(retained[entity] == nil)
        #expect(retained.entities.isEmpty)
    }

    @Test func detachedArraysAndComponentRemainValueSnapshots() {
        let entity = EntityID(index: 1, generation: 0)
        let store = ComponentStore<PositionComponent>()
        let position = PositionComponent(position: .zero)
        store.insert(position, for: entity)
        let dense = store.dense
        let entities = store.entities
        let component = store[entity]

        let updatedPosition = SIMD3<Double>(9, 8, 7)
        store.update(for: entity) { position in
            position.position = updatedPosition
        }
        #expect(store[entity]?.position == updatedPosition)
        store.remove(for: entity)

        #expect(store.dense.isEmpty)
        #expect(store.entities.isEmpty)
        #expect(dense == [position])
        #expect(entities == [entity])
        #expect(component == position)
    }
}
