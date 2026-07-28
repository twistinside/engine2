# Prefer One Capability to Related Escaping Closures

Multiple escaping closures are the wrong dependency shape when they are separate operations on one conceptual resource.
Independent closure parameters let callers combine operations that do not share identity, state, invariants, concurrency
semantics, or even the same value domain.

## Avoid

Do not decompose one clock into independently injectable operations:

```swift
init(
    currentInstant: @escaping @Sendable () -> SuspendingClock.Instant,
    elapsedTime: @escaping @Sendable (SuspendingClock.Instant, SuspendingClock.Instant) -> Duration,
    suspendUntil: @escaping @Sendable (SuspendingClock.Instant) async throws -> Void
) {
    // The caller can accidentally combine unrelated time domains.
}
```

Bundling those closures in a structure without giving the value a coherent capability contract only moves the same
problem. The operations still have no enforced relationship.

## Prefer

Name the shared capability and inject one conforming value:

```swift
protocol PRealtimeClock: Sendable {
    var now: SuspendingClock.Instant { get }

    func sleep(until deadline: SuspendingClock.Instant) async throws
}
```

The consumer then receives one dependency:

```swift
init(clock: any PRealtimeClock) {
    self.clock = clock
}
```

`PRealtimeClock` keeps sampling and absolute suspension in one monotonic instant domain.
`SuspendingRealtimeClock` is the production implementation, while deterministic tests substitute one conforming clock
that owns both operations and their shared state.

Reach for a narrow capability protocol when:

- callers should never choose the operations independently;
- the operations share identity, state, lifecycle, isolation, or invariants;
- a test substitute must coordinate the operations; or
- adding another related operation would otherwise add another escaping closure parameter.

## Keep Genuine One-Operation Policies as Closures

Do not turn every closure into a protocol. A stateless, caller-authored policy with one operation and intentional
call-site capture remains naturally expressed as an escaping closure, particularly when Swift's trailing-closure syntax
makes the injected policy easy to read:

```swift
struct RetryPolicy {
    typealias Decision = @Sendable (any Error) -> Bool

    private let decision: Decision

    init(_ decision: @escaping Decision) {
        self.decision = decision
    }

    func shouldRetry(_ error: any Error) -> Bool {
        decision(error)
    }
}

let retryPolicy = RetryPolicy { error in
    error is TransientConnectionError
}
```

The distinction is conceptual cohesion, not parameter count alone. One stateless operation may be a closure-shaped
policy. Even a one-method collaborator deserves a protocol or concrete type when its identity, lifecycle, state, or
concurrency behavior matters. Several operations that jointly represent one dependency deserve one named capability.
