import Testing
@testable import Engine2

@MainActor
struct DiagnosticsSampleRingTests {
    @Test func newRingIsEmptyAndRetainsItsRequestedCapacity() {
        let ring = DiagnosticsSampleRing(capacity: 3)

        #expect(ring.capacity == 3)
        #expect(ring.count == 0)
        #expect(ring.elements.isEmpty)
    }

    @Test func partialRingPreservesInsertionOrder() {
        var ring = DiagnosticsSampleRing(capacity: 4)
        ring.append(sample(1))
        ring.append(sample(2))

        #expect(ticks(in: ring) == [1, 2])
    }

    @Test func repeatedWraparoundAlwaysReturnsTheNewestWindowInOrder() {
        var ring = DiagnosticsSampleRing(capacity: 3)

        for tick in 1...10 {
            ring.append(sample(UInt64(tick)))
        }

        #expect(ring.count == 3)
        #expect(ticks(in: ring) == [8, 9, 10])
    }

    @Test func removeAllResetsWraparoundStateAndAllowsReuse() {
        var ring = DiagnosticsSampleRing(capacity: 2)
        ring.append(sample(1))
        ring.append(sample(2))
        ring.append(sample(3))

        ring.removeAll()
        ring.append(sample(9))

        #expect(ring.count == 1)
        #expect(ticks(in: ring) == [9])
    }

    private func sample(_ tick: UInt64) -> DiagnosticsSample {
        DiagnosticsSample(
            sessionID: DiagnosticsSessionID(),
            timestamp: DiagnosticsTimestamp(nanosecondsSinceSessionStart: tick),
            category: .simulationLoop,
            payload: .simulationStep(
                SimulationStepDiagnostics(
                    tick: SimulationTick(rawValue: tick),
                    didRunSimulationSystems: true,
                    durationNanoseconds: tick
                )
            )
        )
    }

    private func ticks(in ring: DiagnosticsSampleRing) -> [UInt64] {
        ring.elements.map(\.timestamp.nanosecondsSinceSessionStart)
    }
}
