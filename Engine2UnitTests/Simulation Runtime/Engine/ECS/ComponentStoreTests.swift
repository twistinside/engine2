import Testing
@testable import Engine2

struct ComponentStoreTests {
    @Test func insertAppendsAlignedDenseAndSparseStorage() {
        var store = ComponentStore<CPosition>()
        let first = EntityID(index: 4, generation: 0)
        let second = EntityID(index: 9, generation: 2)

        store.insert(CPosition(position: SIMD3<Float>(1, 2, 3)), for: first)
        store.insert(CPosition(position: SIMD3<Float>(4, 5, 6)), for: second)

        #expect(store.dense.map(\.position) == [SIMD3<Float>(1, 2, 3), SIMD3<Float>(4, 5, 6)])
        #expect(store.entities == [first, second])
        #expect(store.sparse == [4: 0, 9: 1])
        #expect(store[first]?.position == SIMD3<Float>(1, 2, 3))
        #expect(store[second]?.position == SIMD3<Float>(4, 5, 6))
    }

    @Test func insertForExistingEntityReplacesWithoutAppending() {
        var store = ComponentStore<CPosition>()
        let entity = EntityID(index: 3, generation: 1)

        store.insert(CPosition(position: SIMD3<Float>(1, 2, 3)), for: entity)
        store.insert(CPosition(position: SIMD3<Float>(7, 8, 9)), for: entity)

        #expect(store.dense.count == 1)
        #expect(store.entities == [entity])
        #expect(store.sparse == [3: 0])
        #expect(store[entity]?.position == SIMD3<Float>(7, 8, 9))
    }

    @Test func updateMutatesExistingDenseRowAndReportsSuccess() {
        var store = ComponentStore<CPosition>()
        let entity = EntityID(index: 1, generation: 0)
        store.insert(CPosition(position: .zero), for: entity)

        let didUpdate = store.update(for: entity) { position in
            position.position = SIMD3<Float>(3, 4, 5)
        }

        #expect(didUpdate)
        #expect(store[entity]?.position == SIMD3<Float>(3, 4, 5))
    }

    @Test func fullEntityIdentityProtectsLookupAndUpdateFromStaleGeneration() {
        var store = ComponentStore<CPosition>()
        let liveEntity = EntityID(index: 7, generation: 3)
        let staleEntity = EntityID(index: 7, generation: 2)
        store.insert(CPosition(position: SIMD3<Float>(1, 2, 3)), for: liveEntity)

        let didUpdate = store.update(for: staleEntity) { position in
            position.position = SIMD3<Float>(9, 9, 9)
        }

        #expect(store[staleEntity] == nil)
        #expect(didUpdate == false)
        #expect(store[liveEntity]?.position == SIMD3<Float>(1, 2, 3))
    }

    @Test func updateReportsFailureForMissingEntity() {
        var store = ComponentStore<CPosition>()

        let didUpdate = store.update(
            for: EntityID(index: 42, generation: 0)
        ) { position in
            position.position = SIMD3<Float>(1, 1, 1)
        }

        #expect(didUpdate == false)
        #expect(store.dense.isEmpty)
    }

    @Test func largeSparseIndexDoesNotAllocateDensePadding() {
        var store = ComponentStore<CPosition>()
        let entity = EntityID(index: Int.max, generation: 0)

        store.insert(CPosition(position: SIMD3<Float>(1, 2, 3)), for: entity)

        #expect(store.dense.count == 1)
        #expect(store.entities == [entity])
        #expect(store.sparse == [Int.max: 0])
        #expect(store[entity]?.position == SIMD3<Float>(1, 2, 3))
    }

    @Test func failedUpdateNeverExecutesMutationBody() {
        var store = ComponentStore<CPosition>()
        let live = EntityID(index: 3, generation: 2)
        let stale = EntityID(index: 3, generation: 1)
        store.insert(CPosition(position: .zero), for: live)
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
        original.insert(CPosition(position: .zero), for: entity)
        var copy = original

        copy.update(for: entity) { position in
            position.position = SIMD3<Float>(9, 8, 7)
        }

        #expect(original[entity]?.position == .zero)
        #expect(copy[entity]?.position == SIMD3<Float>(9, 8, 7))
    }
}
