# Prefer Throws for Internal Failure Propagation

Within one concrete implementation or tightly owned subsystem, pass a method the values it needs, return its successful
value directly, and throw when it cannot complete. Do not invent request, response, result, outcome, or completion types
merely to carry local control flow between adjacent calls.

Here, "internal" describes an ownership boundary rather than Swift's `internal` access level. An internal protocol can
still be a meaningful Runtime, actor, persistence, or transport boundary.

## Avoid

A caller might wrap the throwing construction of `MetalFrameEncodingInputs` in a private result enum:

```swift
enum FrameInputConstructionResult {
    case accepted(MetalFrameEncodingInputs)
    case rejected(MetalFrameEncoderError)
}

func makeEncodingInputs(...) -> FrameInputConstructionResult {
    do {
        return .accepted(
            try MetalFrameEncodingInputs(
                frameResources: frame,
                sceneColorTexture: sceneTexture,
                depthTexture: depthTexture,
                destinationTexture: destinationTexture,
                clearColor: clearColor,
                outputMode: outputMode,
                exposure: exposure
            )
        )
    } catch {
        return .rejected(error)
    }
}
```

The adjacent call site must switch only to recover ordinary failure control flow:

```swift
switch makeEncodingInputs(...) {
case let .accepted(inputs):
    try frameEncoder.encode(preparedFrame, inputs: inputs, into: commandBuffer)
case let .rejected(error):
    throw error
}
```

The enum adds no durable state, alternate successful value, or boundary information. Replacing it with `Result` changes
the spelling without removing the redundant value-shaped error plumbing.

## Prefer

Let the validated value initializer return its useful value and propagate its typed error directly:

```swift
let inputs = try MetalFrameEncodingInputs(
    frameResources: frame,
    sceneColorTexture: sceneTexture,
    depthTexture: depthTexture,
    destinationTexture: destinationTexture,
    clearColor: clearColor,
    outputMode: outputMode,
    exposure: exposure
)
try frameEncoder.encode(preparedFrame, inputs: inputs, into: commandBuffer)
```

The sequential call site now states the safety order: construction proves the target dimensions and pixel formats agree,
then encoding consumes that validated value. A thrown `MetalFrameEncoderError` carries the failure without a parallel
success/failure vocabulary.

`MetalResourceStore` uses the same shape for construction-time resource ownership. Its initializer asks focused
throwing operations to produce the required resources and dynamic frame storage:

```swift
let residency = try MetalResidencyManager(
    device: device,
    commandQueue: commandQueue,
    staticAssetCapacity: staticAssetCapacity,
    frameResourceCapacity: frameResourceCapacity
)
let requiredResources = try MetalRequiredResources(
    device: device,
    compiler: compiler
)
try makeFrameResources(count: frameCount)
try loadModels(from: renderAssetCatalog)
```

Each operation returns one useful successful value or `Void`. Failure prevents publication of a partially usable store.

Use a focused `Error` type when callers need to distinguish internal failure causes. Typed throws can constrain that
domain when every dependency preserves it without artificial wrapping. Swift calls this feature "typed throws," not
"checked exceptions." Catch only to recover, add meaningful context, translate at a boundary, or perform required
policy; otherwise let the error propagate.

## Keep Values at Real Boundaries

Throwing is not a reason to erase deliberate request and outcome contracts. `SimulationAdvanceTarget` exposes:

```swift
func advance(
    _ request: SimulationAdvanceRequest
) async -> SimulationAdvanceOutcome
```

That call crosses the Simulation Runtime's serialized mutation boundary. Its outcome distinguishes a completed batch
from a request rejected before mutation because the expected and current cursors differ. The rejection retains both
cursors so the caller can reconcile authority without treating expected admission refusal as an exceptional local
failure.

Keep an explicit value when it:

- is stored, replayed, persisted, or sent onward as data;
- crosses an actor, Runtime, protocol, process, or transport boundary;
- preserves request identity, provenance, partial commitment, or retry information;
- represents expected admission, cancellation, or lifecycle states;
- gives the caller multiple successful states rather than one success and one failure.

For adjacent implementation calls, prefer direct parameters, a direct success value, and `throws`.
