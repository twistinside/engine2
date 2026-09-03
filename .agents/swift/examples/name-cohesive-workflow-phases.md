# Name Cohesive Workflow Phases

A coordinating method that owns several substantial operations should read as the ordered domain workflow. Move a
cohesive phase to a private instance method when its implementation detail obscures that workflow and its contract has a
name that clarifies the boundary.

Line count can reveal a problem, but it does not define one. Extract methods to name responsibilities, preserve ordering,
and expose data flow. Do not divide code merely to make the original method shorter.

## Avoid One Method That Hides the Workflow

This abbreviated Simulation advance method validates authority, projects input policy, executes a fixed-step batch,
publishes presentation, and forms the result in one body:

```swift
private func advanceSynchronously(
    _ request: SimulationAdvanceRequest
) -> SimulationAdvanceOutcome {
    let initialCursor = currentCursor
    if let expectedCursor = request.expectedCursor,
       expectedCursor != initialCursor {
        return .rejected(
            .cursorMismatch(
                expected: expectedCursor,
                current: initialCursor
            )
        )
    }

    let firstStepInput: InputSnapshot?
    switch request.inputAssignment {
    case .none:
        firstStepInput = nil
    case let .ingest(snapshot):
        firstStepInput = snapshot
    case let .rebase(snapshot):
        engine.world.input.rebase(to: snapshot)
        firstStepInput = nil
    case let .rebaseThenIngest(baseline, snapshot):
        engine.world.input.rebase(to: baseline)
        firstStepInput = snapshot
    }

    for stepIndex in 0..<request.stepCount.rawValue {
        engine.world.orbitCircularizationCommand = stepIndex == 0
            ? request.orbitCircularizationCommand
            : nil
        engine.step(
            inputSnapshot: stepIndex == 0 ? firstStepInput : nil
        )
    }
    engine.world.orbitCircularizationCommand = nil

    let finalSnapshot = publishPresentationSnapshot(at: engine.completedTick)
    return .completed(
        SimulationAdvanceResult(
            initialCursor: initialCursor,
            finalCursor: currentCursor,
            completedStepCount: SimulationCompletedStepCount(
                rawValue: request.stepCount.rawValue
            ),
            finalPresentationSnapshot: finalSnapshot
        )
    )
}
```

The behavior is sequential, but the reader must discover where each phase begins and which values cross into the next
phase. The input-assignment cases and fixed-step loop obscure the high-level advance contract.

## Prefer a Boundary That States the Domain Workflow

Keep authority admission visible, then name each substantial phase:

```swift
private func advanceSynchronously(
    _ request: SimulationAdvanceRequest
) -> SimulationAdvanceOutcome {
    let initialCursor = currentCursor

    if let expectedCursor = request.expectedCursor,
       expectedCursor != initialCursor {
        return .rejected(
            .cursorMismatch(
                expected: expectedCursor,
                current: initialCursor
            )
        )
    }

    let firstStepInput = prepareFirstStepInput(
        for: request.inputAssignment
    )
    runFixedSteps(
        request.stepCount,
        firstStepInput: firstStepInput,
        firstStepOrbitCircularizationCommand: request.orbitCircularizationCommand
    )

    return .completed(
        publishCompletedAdvanceResult(
            startingAt: initialCursor,
            stepCount: request.stepCount
        )
    )
}
```

The boundary now states the complete workflow:

1. Capture and validate the initial authoritative cursor.
2. Derive the first tick's input treatment.
3. Run the requested complete fixed steps.
4. Publish presentation and form the cursor-correlated result.

The helpers remain private instance methods because they implement one Simulation Runtime's workflow:

| Private method | Cohesive responsibility |
| --- | --- |
| `prepareFirstStepInput(for:)` | Apply baseline policy and return the snapshot assigned to the first tick. |
| `runFixedSteps` | Execute the complete batch and limit transient request values to the first tick. |
| `publishCompletedAdvanceResult(startingAt:stepCount:)` | Publish the final snapshot and form the correlated result. |

## Preserve the Important Story

Keep a guard, state transition, or comment in the coordinating method when its position defines the contract. Extraction
must not hide:

- admission before mutation;
- cancellation before or after an irreversible boundary;
- state ownership transfer;
- isolation or executor boundaries;
- committed bookkeeping before lifecycle exit;
- exhaustive handling of a closed outcome;
- publication before a result becomes observable.

The cursor check remains in `advanceSynchronously(_:)` because it determines whether any mutation may begin. Input
projection stays inside `prepareFirstStepInput(for:)` because rebasing is intrinsic to the treatment that method returns.
Result formation remains at the publication boundary because it preserves the initial cursor, final cursor, completed
step count, and final snapshot as one coherent value.

Name side effects directly. Prefer `publishCompletedAdvanceResult` when a method publishes state and returns a result.
Do not call it `makeResult`, which suggests pure construction. Prefer `runFixedSteps` for the operation that executes the
batch; do not call it `process`, which hides the work performed.

## Keep Small Operations Inline

Do not extract a helper when:

- its name only restates one expression or initializer;
- it has no domain meaning beyond shortening the caller;
- moving it would hide an ordering invariant;
- it separates a value from the guard or state transition that gives it meaning.

The goal is not the fewest lines per method. The goal is a coordinating method whose named phases expose the workflow
without concealing the contract.

Use [Prefer Inline Validation Over One-Use Helpers](prefer-inline-validation-over-one-use-helpers.md) for simple
calculations and checks. Use [Prefer Throws for Internal Failure Propagation](prefer-throws-for-internal-failures.md) when
an extracted phase can return one successful value or throw.
