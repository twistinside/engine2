import Foundation
import Testing
@testable import Engine2

struct RenderViewpointRevisionTests {
    @Test func zeroAndOrdinaryValuesAdvanceMonotonically() {
        let first = RenderViewpointRevision.zero
        let second = first.advanced()
        let ordinary = RenderViewpointRevision(rawValue: 42)
        let penultimate = RenderViewpointRevision(rawValue: .max - 1)

        #expect(first.rawValue == 0)
        #expect(second.rawValue == 1)
        #expect(first < second)
        #expect(ordinary.advanced().rawValue == 43)
        #expect(penultimate.advanced().rawValue == .max)
    }

    @Test func rawAndCodableRoundTripsPreserveBoundaryValues() throws {
        let revisions = [
            RenderViewpointRevision.zero,
            RenderViewpointRevision(rawValue: 42),
            RenderViewpointRevision(rawValue: .max - 1),
            RenderViewpointRevision(rawValue: .max)
        ]

        for revision in revisions {
            #expect(Self.rawRoundTrip(revision) == revision)
            let data = try JSONEncoder().encode(revision)
            #expect(
                try JSONDecoder().decode(
                    RenderViewpointRevision.self,
                    from: data
                ) == revision
            )
        }
        #expect(revisions[0] < revisions[1])
        #expect(revisions[1] < revisions[2])
        #expect(revisions[2] < revisions[3])
    }

    private static func rawRoundTrip<Value>(
        _ value: Value
    ) -> Value? where Value: Equatable & RawRepresentable {
        Value(rawValue: value.rawValue)
    }
}
