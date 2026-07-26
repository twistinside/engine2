import Foundation
import Testing
@testable import Engine2

struct SimulationTickTests {
    @Test func advancedReturnsNextStronglyTypedIdentity() {
        let tick = SimulationTick(rawValue: 41)
        let expected = SimulationTick(rawValue: 42)

        #expect(tick.advanced() == expected)
        #expect(SimulationTick.zero < tick)
    }

    @Test func orderingHandlesFullUnsignedRange() {
        let values = [
            SimulationTick(rawValue: .max),
            .zero,
            SimulationTick(rawValue: .max - 1),
            SimulationTick(rawValue: 1)
        ]
        let expected = [
            SimulationTick.zero,
            SimulationTick(rawValue: 1),
            SimulationTick(rawValue: .max - 1),
            SimulationTick(rawValue: .max)
        ]

        #expect(values.sorted() == expected)
        requireRawRepresentable(SimulationTick.zero)
    }

    @Test func codableRoundTripPreservesLargeTickIdentity() throws {
        let tick = SimulationTick(rawValue: .max - 1)

        let data = try JSONEncoder().encode(tick)
        let decoded = try JSONDecoder().decode(SimulationTick.self, from: data)

        let expected = SimulationTick(rawValue: .max)

        #expect(decoded == tick)
        #expect(decoded.advanced() == expected)
    }

    @Test func tickIsSafeToTransferAsAnImmutableBoundaryValue() {
        let tick = SimulationTick(rawValue: 8)

        requireSendable(tick)
    }

    private func requireSendable(_ value: some Sendable) {}
    private func requireRawRepresentable(_ value: some RawRepresentable) {}
}
