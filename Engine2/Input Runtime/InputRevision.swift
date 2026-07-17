//
//  InputRevision.swift
//  Engine2
//
//  Created by Codex on 7/16/26.
//

/// Monotonic identity for an immutable value published by `InputRuntime`.
///
/// A new session starts whenever the runtime is restarted. Sequence numbers
/// order publications within that session.
struct InputRevision: Equatable, Comparable, Sendable {
    let session: UInt64
    let sequence: UInt64

    static let initial = InputRevision(session: 0, sequence: 0)

    static func < (lhs: InputRevision, rhs: InputRevision) -> Bool {
        if lhs.session == rhs.session {
            lhs.sequence < rhs.sequence
        } else {
            lhs.session < rhs.session
        }
    }

    func advanced() -> InputRevision {
        precondition(sequence < .max, "Input revision sequence exhausted")
        return InputRevision(session: session, sequence: sequence + 1)
    }

    func startingNextSession() -> InputRevision {
        precondition(session < .max, "Input revision session exhausted")
        return InputRevision(session: session + 1, sequence: 0)
    }
}
