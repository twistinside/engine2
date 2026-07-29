import Testing
@testable import Engine2
@testable import Engine2RealtimeAssembly

struct EntityMotionPaneTests {
    @Test func rowsExtractPositionSpeedAndDisplayText() throws {
        let stationary = EntityID(index: 0, generation: 0)
        let moving = EntityID(index: 1, generation: 0)
        let snapshots = [
            EntityMotionSnapshot(
                id: stationary,
                position: SIMD3<Float>(1, -2, 3.125),
                velocity: .zero
            ),
            EntityMotionSnapshot(
                id: moving,
                position: SIMD3<Float>(4, 5, 6),
                velocity: SIMD3<Float>(3, 4, 0)
            )
        ]

        let rows = EntityMotionRow.extract(from: snapshots)

        #expect(rows.count == 2)
        #expect(rows[0].id == stationary)
        #expect(rows[0].speed == 0)
        #expect(rows[0].locationText == "(1.00, -2.00, 3.12)")
        #expect(rows[0].speedText == "0.00")
        #expect(rows[1].id == moving)
        #expect(rows[1].speed == 5)
        #expect(rows[1].locationText == "(4.00, 5.00, 6.00)")
        #expect(rows[1].speedText == "5.00")
    }
}
