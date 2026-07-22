import Testing
@testable import Engine2

struct InputRevisionTests {
    @Test func initialRevisionIsTheOriginOfTheFirstSession() {
        #expect(InputRevision.initial == InputRevision(session: 0, sequence: 0))
    }

    @Test func advancingPreservesSessionAndIncrementsOnlySequence() {
        let revision = InputRevision(session: 7, sequence: 41)

        #expect(revision.advanced() == InputRevision(session: 7, sequence: 42))
    }

    @Test func startingNextSessionResetsSequenceEvenAfterManyPublications() {
        let revision = InputRevision(session: 7, sequence: 9_999)

        #expect(revision.startingNextSession() == InputRevision(session: 8, sequence: 0))
    }

    @Test func orderingIsLexicographicBySessionThenSequence() {
        let revisions = [
            InputRevision(session: 2, sequence: 1),
            InputRevision(session: 1, sequence: .max),
            InputRevision(session: 2, sequence: 0),
            InputRevision(session: 1, sequence: 0)
        ]

        #expect(revisions.sorted() == [
            InputRevision(session: 1, sequence: 0),
            InputRevision(session: 1, sequence: .max),
            InputRevision(session: 2, sequence: 0),
            InputRevision(session: 2, sequence: 1)
        ])
    }
}
