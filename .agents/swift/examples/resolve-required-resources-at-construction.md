# Resolve Required Resources at Construction

When a required resource is selected through a string or another fragile external identity and acquisition can fail,
resolve it at the owning object's construction boundary. Retain the resulting typed handle and let downstream code use
that handle without repeating the identifier, lookup, or fallibility.

"Early" means before the owner is published as ready, not necessarily at process launch. The Runtime or resource store
that owns the resource should also own the failure.

## Avoid Replaying Construction Failure

Before the required-resource set was explicit, `MetalResourceStore` compiled every required built-in render pipeline
during initialization:

```swift
try loadRenderPipeline(.modelPBR)
try loadRenderPipeline(.modelNormalDiagnostic)
try loadRenderPipeline(.hdrToneMappedPresentation)
try loadRenderPipeline(.linearPresentation)
```

Compilation mapped each closed pipeline identity to string-named Metal shader entry points and asked `MTL4Compiler` to
create the pipeline state. A misspelled vertex or fragment name therefore failed store construction, before frame
encoding began.

Apple's [Metal 4 compilation guidance][metal4-compilation] makes compilation timing an explicit renderer decision. For
Engine2's small closed required set, store construction is the predictable point to surface those failures.

Downstream objects nevertheless replayed a second, ordinary failure path:

```swift
init(resources: MetalResourceStore) throws {
    self.toneMappedPipeline = try resources.renderPipelineState(for: .hdrToneMappedPresentation)
    self.linearPipeline = try resources.renderPipelineState(for: .linearPresentation)
    self.argumentTable = try resources.argumentTable(for: .hdrPresentation)
}
```

The accessor treated an absent cache row as recoverable:

```swift
func renderPipelineState(for id: MetalRenderPipelineID) throws -> any MTLRenderPipelineState {
    guard let state = renderPipelineStates[id] else {
        throw MetalResourceStoreError.missingRenderPipeline(id)
    }

    return state
}
```

After successful construction, the private cache had no expected removal path. A missing required pipeline meant the
store's construction invariant was broken, not that a later consumer encountered a new operational failure. Keeping
the lookup throwing:

- makes every consumer propagate an impossible ordinary error;
- obscures which initialization boundary actually compiles and validates the resource;
- leaves room for a new closed identity and the eager-loading list to drift apart;
- encourages raw or string-derived identities to leak toward frame encoding.

## Prefer One Fallible Boundary

Keep string names inside the resource owner, compile the small closed required set there, and retain the successful
pipeline states as nonoptional typed resources. Metal 4 expresses the string boundary through
`MTL4LibraryFunctionDescriptor` and validates the complete descriptor when `MTL4Compiler` creates the pipeline state:

```swift
let vertexFunction = MTL4LibraryFunctionDescriptor()
vertexFunction.library = library
vertexFunction.name = "hdrPresentationVertex"

let fragmentFunction = MTL4LibraryFunctionDescriptor()
fragmentFunction.library = library
fragmentFunction.name = "hdrToneMappedPresentationFragment"

let descriptor = MTL4RenderPipelineDescriptor()
descriptor.label = "HDR Tone-Mapped Presentation Pipeline"
descriptor.vertexFunctionDescriptor = vertexFunction
descriptor.fragmentFunctionDescriptor = fragmentFunction
descriptor.colorAttachments[0].pixelFormat = MetalFrameEncoder.destinationColorPixelFormat

hdrToneMappedPresentationPipeline = try compiler.makeRenderPipelineState(descriptor: descriptor)
```

Retain the highest-level typed resource downstream code actually uses. In this path, encoders need the compiled pipeline
state; the string-named function descriptors are construction inputs and do not need to remain part of the runtime API.

Construction still throws because shader lookup and pipeline compilation can genuinely fail. Once it succeeds, expose
the retained resource directly or through a nonthrowing required-resource view:

```swift
init(resources: MetalResourceStore) {
    self.toneMappedPipeline = resources.hdrToneMappedPresentationPipeline
    self.linearPipeline = resources.linearPresentationPipeline
    self.argumentTable = resources.hdrPresentationArgumentTable
}
```

Successful construction removes availability fallibility; it does not make a handle immutable, thread-safe,
device-independent, or valid outside its owner's lifetime. Preserve the resource's isolation and lifecycle rules.
Engine2's mutable argument tables, for example, still belong to their serialized Render owner.

Direct nonoptional properties, or a focused value containing the complete required resource set, provide the strongest
shape. When a closed-ID dictionary is preferable for scale, populate it exhaustively before initialization completes.
Make missing access an invariant violation rather than an ordinary recoverable result, and test that every closed
identity is constructed.

`MetalResourceStore.materialDescription(for:)` already follows the same post-validation principle: store construction
proves exhaustive finite `MaterialID` coverage, immutable storage retains it, and later frame preparation performs a
nonthrowing lookup. Its force unwrap is justified by that invariant, not recommended as a general lookup strategy.

Models deliberately have a different contract. Their string-backed asset references are resolved and decoded during
store construction, but `model(for:)` remains optional because the configured catalog need not contain every mesh. The
live renderer permits omission. Do not turn optional content into a required resource merely to remove an optional.

This complements [Prefer Throws for Internal Failure Propagation](prefer-throws-for-internal-failures.md): throw while
constructing or validating the resource, then remove that fallibility from code whose inputs already prove the resource
exists.

## Keep Dynamic Resources Dynamic

Do not eagerly create a resource before the information required to create it exists. Delayed or fallible access remains
appropriate when:

- content is optional, streamed, hot-reloaded, supplied by a plugin, or selected from an open vocabulary;
- availability can legitimately change after initialization;
- dimensions or formats depend on a future drawable, request, device capability, or negotiated output;
- a large or rarely used resource has an intentional demand-driven caching policy;
- device loss or Runtime rebuild invalidates the previously retained handle.

Even then, resolve string identities at the narrowest controlled setup point, cache successful typed handles when their
lifetime permits it, and keep lookup or creation out of the frame hot path. For example, a drawable-sized texture cannot
be finalized before its size is known. `FrameResources.prepareHDRSceneTarget` creates or replaces that target only after
the caller owns the frame slot and knows the requested size, then reuses it until the size changes.

The rule is not "allocate everything immediately." The rule is that a type claiming to own a complete required resource
set should either fail before becoming usable or thereafter provide those resources without pretending absence is an
ordinary downstream event.

[metal4-compilation]: https://developer.apple.com/documentation/metal/using-the-metal-4-compilation-api
