import Testing
@testable import Engine2

struct ComponentStoreTests {
    @Test func insertAppendsAlignedDenseAndSparseStorage() {
        var store = ComponentStore<CPosition>()
        let first = EntityID(index: 4, generation: 0)
        let second = EntityID(index: 9, generation: 2)
        let firstPositionValue = SIMD3<Double>(1, 2, 3)
        let secondPositionValue = SIMD3<Double>(4, 5, 6)
        let firstPosition = CPosition(position: firstPositionValue)
        let secondPosition = CPosition(position: secondPositionValue)

        store.insert(firstPosition, for: first)
        store.insert(secondPosition, for: second)

        let expectedPositions = [firstPositionValue, secondPositionValue]

        #expect(store.dense.map(\.position) == expectedPositions)
        #expect(store.entities == [first, second])
        #expect(store.sparse == [4: 0, 9: 1])
        #expect(store[first]?.position == firstPositionValue)
        #expect(store[second]?.position == secondPositionValue)
    }

    @Test func insertForExistingEntityReplacesWithoutAppending() {
        var store = ComponentStore<CPosition>()
        let entity = EntityID(index: 3, generation: 1)
        let replacementPositionValue = SIMD3<Double>(7, 8, 9)
        let initialPosition = CPosition(position: SIMD3<Double>(1, 2, 3))
        let replacementPosition = CPosition(position: replacementPositionValue)

        store.insert(initialPosition, for: entity)
        store.insert(replacementPosition, for: entity)

        #expect(store.dense.count == 1)
        #expect(store.entities == [entity])
        #expect(store.sparse == [3: 0])
        #expect(store[entity]?.position == replacementPositionValue)
    }

    @Test func updateMutatesExistingDenseRowAndReportsSuccess() {
        var store = ComponentStore<CPosition>()
        let entity = EntityID(index: 1, generation: 0)
        let position = CPosition(position: .zero)
        store.insert(position, for: entity)

        let expectedPosition = SIMD3<Double>(3, 4, 5)
        let didUpdate = store.update(for: entity) { position in
            position.position = expectedPosition
        }

        #expect(didUpdate)
        #expect(store[entity]?.position == expectedPosition)
    }

    @Test func fullEntityIdentityProtectsLookupAndUpdateFromStaleGeneration() {
        var store = ComponentStore<CPosition>()
        let liveEntity = EntityID(index: 7, generation: 3)
        let staleEntity = EntityID(index: 7, generation: 2)
        let livePositionValue = SIMD3<Double>(1, 2, 3)
        let livePosition = CPosition(position: livePositionValue)
        store.insert(livePosition, for: liveEntity)

        let didUpdate = store.update(for: staleEntity) { position in
            position.position = SIMD3<Double>(9, 9, 9)
        }

        #expect(store[staleEntity] == nil)
        #expect(didUpdate == false)
        #expect(store[liveEntity]?.position == livePositionValue)
    }

    @Test func updateReportsFailureForMissingEntity() {
        var store = ComponentStore<CPosition>()
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
        var store = ComponentStore<CPosition>()
        let entity = EntityID(index: Int.max, generation: 0)
        let positionValue = SIMD3<Double>(1, 2, 3)
        let position = CPosition(position: positionValue)

        store.insert(position, for: entity)

        #expect(store.dense.count == 1)
        #expect(store.entities == [entity])
        #expect(store.sparse == [Int.max: 0])
        #expect(store[entity]?.position == positionValue)
    }

    @Test func failedUpdateNeverExecutesMutationBody() {
        var store = ComponentStore<CPosition>()
        let live = EntityID(index: 3, generation: 2)
        let stale = EntityID(index: 3, generation: 1)
        let position = CPosition(position: .zero)
        store.insert(position, for: live)
        var invocationCount = 0

        let didUpdate = store.update(for: stale) { _ in
            invocationCount += 1
        }

        #expect(didUpdate == false)
        #expect(invocationCount == 0)
    }

    @Test func copiedStoreHasIndependentValueSemantics() {
        let entity = EntityID(index: 1, generation: 0)
        var original = ComponentStore<CPosition>()
        let position = CPosition(position: .zero)
        original.insert(position, for: entity)
        var copy = original

        let updatedPosition = SIMD3<Double>(9, 8, 7)
        copy.update(for: entity) { position in
            position.position = updatedPosition
        }

        #expect(original[entity]?.position == .zero)
        #expect(copy[entity]?.position == updatedPosition)
    }
}
