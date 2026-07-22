import Testing
@testable import Engine2

struct InputSnapshotTests {
    @Test func emptySnapshotIsCompletelyNeutral() {
        let snapshot = InputSnapshot.empty

        #expect(snapshot.revision == .initial)
        #expect(snapshot.pointerPosition == .zero)
        #expect(snapshot.pointerMotionTotal == .zero)
        #expect(snapshot.scrollTotal == .zero)
        #expect(snapshot.pressedMouseButtons.isEmpty)
        #expect(snapshot.pressedKeys.isEmpty)
    }

    @Test func equalityUsesSetValuesRatherThanInsertionOrder() {
        let firstKey = KeyboardKey(keyCode: 1, displayName: "A")
        let secondKey = KeyboardKey(keyCode: 2, displayName: "B")
        let first = InputSnapshot(
            revision: InputRevision(session: 1, sequence: 2),
            pointerPosition: SIMD2<Float>(3, 4),
            pointerMotionTotal: SIMD2<Float>(5, 6),
            scrollTotal: SIMD2<Float>(7, 8),
            pressedMouseButtons: [.left, .other(4)],
            pressedKeys: [firstKey, secondKey]
        )
        let second = InputSnapshot(
            revision: InputRevision(session: 1, sequence: 2),
            pointerPosition: SIMD2<Float>(3, 4),
            pointerMotionTotal: SIMD2<Float>(5, 6),
            scrollTotal: SIMD2<Float>(7, 8),
            pressedMouseButtons: [.other(4), .left],
            pressedKeys: [secondKey, firstKey]
        )

        #expect(first == second)
    }

    @Test func revisionRemainsPartOfSnapshotValueIdentity() {
        let first = InputSnapshot(
            revision: InputRevision(session: 1, sequence: 1),
            pointerPosition: .zero,
            pointerMotionTotal: .zero,
            scrollTotal: .zero,
            pressedMouseButtons: [],
            pressedKeys: []
        )
        let second = InputSnapshot(
            revision: InputRevision(session: 1, sequence: 2),
            pointerPosition: .zero,
            pointerMotionTotal: .zero,
            scrollTotal: .zero,
            pressedMouseButtons: [],
            pressedKeys: []
        )

        #expect(first != second)
    }
}
