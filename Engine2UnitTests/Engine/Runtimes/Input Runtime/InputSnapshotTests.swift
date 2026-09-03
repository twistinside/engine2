import Testing
@testable import Engine2

struct InputSnapshotTests {
    @Test func emptySnapshotIsCompletelyNeutral() {
        let snapshot = InputSnapshot.empty

        #expect(snapshot.revision == .initial)
        #expect(snapshot.translation == .zero)
        #expect(snapshot.isInteractionActive == false)
        #expect(snapshot.cameraOrbitTotal == .zero)
        #expect(snapshot.cameraZoomTotal == 0)
        #expect(snapshot.latestSelectionPress == nil)
        #expect(snapshot.selectionPressCount == 0)
    }

    @Test func everySemanticFieldParticipatesInValueIdentity() throws {
        let selectionPress = try #require(
            SelectionPress(
                normalizedPosition: SIMD2<Float>(0.25, 0.75),
                aspectRatio: 2
            )
        )
        let first = InputSnapshot(
            revision: InputRevision(session: 1, sequence: 2),
            translation: SIMD2<Float>(1, 0),
            isInteractionActive: true,
            cameraOrbitTotal: SIMD2<Float>(3, 4),
            cameraZoomTotal: 5,
            latestSelectionPress: selectionPress,
            selectionPressCount: 6
        )

        #expect(first != .empty)
        #expect(InputSnapshot(
            revision: .init(advancing: first.revision),
            translation: first.translation,
            isInteractionActive: first.isInteractionActive,
            cameraOrbitTotal: first.cameraOrbitTotal,
            cameraZoomTotal: first.cameraZoomTotal,
            latestSelectionPress: first.latestSelectionPress,
            selectionPressCount: first.selectionPressCount
        ) != first)
    }
}
