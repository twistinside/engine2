# Prefer Throws for Internal Failure Propagation

Within one concrete implementation or tightly owned subsystem, pass a method the values it needs, return its successful
value directly, and throw when it cannot complete. Do not invent request, response, result, outcome, or completion types
merely to carry local control flow between adjacent calls.

Here, "internal" describes an ownership boundary rather than Swift's `internal` access level. An internal protocol can
still be a meaningful runtime, actor, persistence, or transport boundary.

## Avoid

The offscreen Metal implementation currently turns queue feedback into a private two-case completion value:

```swift
nonisolated enum MetalOffscreenCompletion: Equatable, Sendable {
    case success
    case failure(String)
}
```

That value is awaited, switched only to recover the failure, and then passed into readback as a success token:

```swift
let completion = await commit(commandBuffer, frame: frame, sceneTarget: sceneTarget, targets: targets)

switch completion {
case .success:
    break
case let .failure(description):
    let failure = OffscreenRenderFailure(stage: .gpuExecution, backendDescription: description)
    renderingState = .failed(failure)
    return .failed(failure)
}

let image = try targets.readback(after: completion)
```

Inside this implementation, `.success` carries no value and `.failure` is immediately converted into failure control
flow. The completion enum, nonthrowing continuation payload, switch, and readback parameter all exist to manually encode
what a successful return or thrown error already means. The success token is also freely constructible, so it does not
provide a strong sequencing guarantee.

Do not replace a custom response enum with `Result` when the caller will immediately switch and rethrow it. That changes
the spelling without removing the local value-shaped error plumbing.

## Prefer

Make the private asynchronous commit operation return `Void` on success and throw on failed queue feedback. Catch it
where the concrete runtime translates backend failure into its public outcome:

```swift
do {
    try await commit(commandBuffer, frame: frame, sceneTarget: sceneTarget, targets: targets)
} catch {
    let failure = OffscreenRenderFailure(stage: .gpuExecution, backendDescription: String(describing: error))
    renderingState = .failed(failure)
    return .failed(failure)
}

let image = try targets.readback()
```

The sequential call site now states the safety order directly: a successful `commit` return means queue feedback has
arrived, so readback may begin. A throwing continuation can carry the asynchronous failure without constructing a
parallel success/failure result vocabulary.

`MetalResourceStore` already demonstrates this shape for synchronous internal work:

```swift
try makeFrameResources(count: frameCount)
try loadShaderLibrary(.engine)
try loadRenderPipeline(.modelPBR)
try loadModels(from: renderAssetCatalog)
```

Its helpers return only useful successful values or `Void`, while errors propagate naturally:

```swift
private func makeFrameResources(count: Int) throws {
    for _ in 0..<count {
        guard let commandAllocator = device.makeCommandAllocator(),
              let instanceBuffer = device.makeBuffer(
                length: MemoryLayout<GPUInstance>.stride * FrameResources.maximumInstanceCount,
                options: [.storageModeShared]
              )
        else {
            throw MetalResourceStoreError.missingFrameResource
        }

        // Retain the successfully created resources.
    }
}
```

Use a focused `Error` type when callers need to distinguish internal failure causes. Typed throws can further constrain
that domain when all dependencies support it without extra wrapping. Catch only to recover, add meaningful context,
translate at a boundary, or perform required policy; otherwise let the error propagate.

## Keep Values at Real Boundaries

Throwing is not a reason to erase deliberate request and outcome contracts. `POffscreenRenderTarget` correctly exposes:

```swift
func render(_ request: OffscreenRenderRequest) async -> OffscreenRenderOutcome
```

That call crosses a Runtime capability boundary. Its outcome represents expected admission refusal, accepted-request
failure, post-submission cancellation, and exact request correlation. Those states are contract data that callers must
handle exhaustively, not merely local implementation failures.

Likewise, Agent Session outcomes carry idempotent replay, in-progress identity, sequence rejection, retained responses,
and authoritative cursor knowledge. A thrown error alone would discard information that remains meaningful after the
operation returns.

Keep an explicit value when it:

- is stored, replayed, persisted, or sent onward as data;
- crosses an actor, runtime, protocol, process, or transport boundary;
- preserves request identity, provenance, partial commitment, or retry information;
- represents expected admission, cancellation, or lifecycle states;
- gives the caller multiple successful states rather than one success and one failure.

For adjacent implementation calls, prefer direct parameters, a direct success value, and `throws`.
