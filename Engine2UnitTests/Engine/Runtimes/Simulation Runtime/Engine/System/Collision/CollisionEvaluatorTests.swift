import Testing
@testable import Engine2

struct CollisionEvaluatorTests {
    @Test func reversedInputsPreserveTheCanonicalPairAndNormal() throws {
        let first = CollisionSweep(
            entityID: EntityID(index: 4, generation: 2),
            previousPosition: SIMD2<Double>(-10, 0),
            position: SIMD2<Double>(10, 0),
            radius: 1,
            travelFraction: 1
        )
        let second = CollisionSweep(
            entityID: EntityID(index: 4, generation: 3),
            previousPosition: .zero,
            position: .zero,
            radius: 1,
            travelFraction: 1
        )
        let evaluator = CollisionEvaluator()

        let forward = try #require(evaluator.contact(between: first, and: second))
        let reversed = try #require(evaluator.contact(between: second, and: first))

        #expect(forward.firstEntityID == first.entityID)
        #expect(forward.secondEntityID == second.entityID)
        #expect(reversed.firstEntityID == first.entityID)
        #expect(reversed.secondEntityID == second.entityID)
        #expect(forward.normal == SIMD2<Double>(-1, 0))
        #expect(reversed.normal == forward.normal)
        #expect(forward.tickFraction == 0.4)
        #expect(reversed.tickFraction == forward.tickFraction)
    }

    @Test func coincidentStationaryInputsHaveTheSameFallbackNormalInEitherOrder() throws {
        let first = CollisionSweep(
            entityID: EntityID(index: 0, generation: 0),
            previousPosition: .zero,
            position: .zero,
            radius: 1,
            travelFraction: 1
        )
        let second = CollisionSweep(
            entityID: EntityID(index: 1, generation: 0),
            previousPosition: .zero,
            position: .zero,
            radius: 1,
            travelFraction: 1
        )
        let evaluator = CollisionEvaluator()

        let forward = try #require(evaluator.contact(between: first, and: second))
        let reversed = try #require(evaluator.contact(between: second, and: first))

        #expect(forward.normal == SIMD2<Double>(1, 0))
        #expect(reversed.normal == forward.normal)
        #expect(forward.tickFraction == 0)
        #expect(reversed.tickFraction == 0)
    }

    @Test func initialOverlapUsesRelativeMotionWhenTheImpactNormalIsUndefined() throws {
        let first = CollisionSweep(
            entityID: EntityID(index: 0, generation: 0),
            previousPosition: .zero,
            position: SIMD2<Double>(1, 0),
            radius: 1,
            travelFraction: 1
        )
        let second = CollisionSweep(
            entityID: EntityID(index: 1, generation: 0),
            previousPosition: .zero,
            position: .zero,
            radius: 1,
            travelFraction: 1
        )
        let evaluator = CollisionEvaluator()

        let forward = try #require(evaluator.contact(between: first, and: second))
        let reversed = try #require(evaluator.contact(between: second, and: first))

        #expect(forward.normal == SIMD2<Double>(-1, 0))
        #expect(reversed.normal == forward.normal)
        #expect(forward.tickFraction == 0)
    }
}
