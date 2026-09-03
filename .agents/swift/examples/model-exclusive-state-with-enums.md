# Model Mutually Exclusive State with Enums

When several flags and optional payloads describe one mutually exclusive state, represent that state with an enum and
carry case-specific data as associated values. The compiler should make invalid combinations unrepresentable.

Do not combine independent dimensions merely because they belong to one object. Model only the values that must
transition together; keep genuinely orthogonal operation, lifecycle, and cancellation state separate.

## Avoid

```swift
private(set) var isAdvancementEnabled = true
private(set) var isPaused = false
private(set) var authorityFault: RealtimeAdvanceDriverFault?
```

These properties attempt to describe one advancement-policy state, but they permit combinations that have no meaning:

- advancement can be both enabled and paused;
- a fault can coexist with enabled advancement;
- a driver can be neither enabled nor paused without carrying a fault;
- clearing the fault can leave policy in an indeterminate state.

Every transition must coordinate several assignments correctly:

```swift
isAdvancementEnabled = false
isPaused = false
authorityFault = .cursorMismatch(
    expected: expectedCursor,
    current: currentCursor
)
```

The compiler cannot detect a forgotten assignment or prevent another method from creating an impossible combination.

## Prefer

Define the closed policy state in its own file. Each case carries exactly the data valid in that state:

```swift
/// Mutually exclusive user policy and authority health for real-time advance.
enum RealtimeAdvancementState {
    case enabled
    case paused
    case faulted(RealtimeAdvanceDriverFault)
}
```

The driver stores one state:

```swift
private(set) var advancementState: RealtimeAdvancementState
```

The associated value ensures a faulted state always identifies the authority mismatch, while `.enabled` and `.paused`
cannot retain a stale fault. Transitions become single assignments:

```swift
advancementState = .enabled
advancementState = .paused
advancementState = .faulted(
    .cursorMismatch(
        expected: expectedCursor,
        current: currentCursor
    )
)
```

Code that handles the policy state must be exhaustive:

```swift
switch advancementState {
case .enabled:
    requestElapsedSteps()
case .paused:
    discardElapsedSteps()
case let .faulted(fault):
    reportAuthorityFault(fault)
}
```

Derive narrower projections without storing another source of truth:

```swift
var isAdvancementEnabled: Bool {
    advancementState == .enabled
}

var fault: RealtimeAdvanceDriverFault? {
    guard case let .faulted(fault) = advancementState else {
        return nil
    }
    return fault
}
```

## Keep Independent State Independent

An enum should encode exclusivity, not force unrelated facts into one combinatorial state machine. In the real-time
driver, playback policy, polling lifecycle, and in-flight work answer different questions. The latter two remain separate:

```swift
private(set) var advancementState: RealtimeAdvancementState
private(set) var isRunning = false
private(set) var isQuiescent = true
```

A paused driver may continue polling so it can observe lifecycle policy, while a stopped driver may retain enabled policy
for a later run. Either policy may temporarily coexist with unsettled accepted work while the driver drains. Combining all
three dimensions into one enum would multiply cases without making an invariant clearer.

Keep a `Bool` for a genuinely independent binary fact. Use separate enums for orthogonal state dimensions. Introduce one
enum when multiple properties must change together and only a finite set of combinations is valid.
