import Foundation
import Testing
@testable import Engine2

struct SimulationTickTests {
    @Test func advancedReturnsNextStronglyTypedIdentity() {
        let tick = SimulationTick(rawValue: 41)

        #expect(tick.advanced() == SimulationTick(rawValue: 42))
        #expect(SimulationTick.zero < tick)
    }

    @Test func orderingHandlesFullUnsignedRange() {
        let values = [
            SimulationTick(rawValue: .max),
            .zero,
            SimulationTick(rawValue: .max - 1),
            SimulationTick(rawValue: 1)
        ]

        #expect(values.sorted() == [
            .zero,
            SimulationTick(rawValue: 1),
            SimulationTick(rawValue: .max - 1),
            SimulationTick(rawValue: .max)
        ])
    }

    @Test func codableRoundTripPreservesLargeTickIdentity() throws {
        let tick = SimulationTick(rawValue: .max - 1)

        let data = try JSONEncoder().encode(tick)
        let decoded = try JSONDecoder().decode(SimulationTick.self, from: data)

        #expect(decoded == tick)
        #expect(decoded.advanced() == SimulationTick(rawValue: .max))
    }
}
