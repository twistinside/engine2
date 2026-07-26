# Choose the Construction Form That Expresses Intent

Initializers, convenience initializers, named static values, static factories,
and default arguments communicate different semantics. Do not choose among
them merely by which form makes a call site shortest.

| Intent | Swift form |
| --- | --- |
| Construct a caller-selected combination of values | Full initializer call; synthesized when sufficient |
| Give a class a secondary path that supplies ordinary local state | `convenience init` |
| Expose a distinguished, complete value | `static let` |
| Perform a named loading, caching, or implementation-selection process | `static func` |
| Let a caller silently omit a choice | Default argument, exceptionally |

## Use the Full Initializer for Caller-Selected Values

The full initializer is the baseline construction surface. It lets the caller
state the complete value it wants without hiding a choice.

```swift
let catalog = RenderAssetCatalog(models: selectedModels, materials: selectedMaterials)
```

For a class, this complete initialization path is normally a designated
initializer. Structures and enumerations also have initializers, but Swift does
not call them designated initializers.

Keep a one-off combination at its composition site when it has no stable domain
meaning. Do not add a named preset merely because the initializer is long.

### Name Meaningful Nested Construction

A substantial constructed value remains a separate decision even when another
object immediately owns it. Do not bury that decision inside a second
multiline initializer:

```swift
// Avoid: the Simulation Runtime disappears inside assembly punctuation.
ManualAssembly(
    simulationRuntime: SimulationRuntime(
        worldBuilder: gameContent.worldBuilder,
        configuration: gameContent.simulationConfiguration,
        inputBaseline: nil,
        sessionID: sessionID
    )
)
```

Bind the inner value to a role-named local, then construct the owner:

```swift
let simulationRuntime = SimulationRuntime(
    worldBuilder: gameContent.worldBuilder,
    configuration: gameContent.simulationConfiguration,
    inputBaseline: nil,
    sessionID: sessionID
)
return ManualAssembly(simulationRuntime: simulationRuntime)
```

This exposes both construction boundaries and gives later validation,
configuration, or debugging a natural seam. Keep tiny value projections, enum
cases, and declarative builder or modifier values inline when extracting them
would merely replace a clear label with a redundant local name.

### Let Swift Synthesize Plain Memberwise Construction

Choosing a full initializer at the call site does not mean hand-writing one in
the type. For a structure, use the synthesized memberwise initializer when its
stored properties already define exactly the intended internal construction
surface.

Avoid an initializer that only repeats property names and assignments:

```swift
struct AgentSessionRequestID {
    let sessionID: AgentSessionID
    let sequence: AgentSessionRequestSequence

    init(sessionID: AgentSessionID, sequence: AgentSessionRequestSequence) {
        self.sessionID = sessionID
        self.sequence = sequence
    }
}
```

Prefer the equivalent synthesized construction:

```swift
struct AgentSessionRequestID {
    let sessionID: AgentSessionID
    let sequence: AgentSessionRequestSequence
}

let requestID = AgentSessionRequestID(sessionID: sessionID, sequence: sequence)
```

Write an explicit initializer when it validates or normalizes input, delegates,
changes argument labels, exposes different access, supplies deliberate defaults,
or satisfies a protocol requirement. An explicit initializer may also be needed
when another initializer suppresses memberwise synthesis. Classes and actors do
not receive a synthesized memberwise initializer, and a public construction API
may require an explicitly public initializer.

## Use a Convenience Initializer for a Class's Secondary Path

A Swift convenience initializer is a class-only initialization path. It must
delegate to another initializer on the same class and ultimately reach a
designated initializer. It is not a synonym for a static factory method or any
initializer that happens to be shorter.

It is appropriate when callers must still provide identity, ownership, or
connection values while the class supplies ordinary state that each instance
may safely choose independently.

The current `SimulationRuntime` uses this distinction directly:

```swift
final class SimulationRuntime {
    init(
        worldBuilder: any PWorldBuilder,
        configuration: SimulationConfiguration,
        inputBaseline: InputSnapshot?,
        sessionID: SimulationSessionID
    ) {
        // Construct the authoritative session.
    }

    /// Starts a fresh authoritative timeline.
    convenience init(
        worldBuilder: any PWorldBuilder,
        configuration: SimulationConfiguration,
        inputBaseline: InputSnapshot?
    ) {
        self.init(
            worldBuilder: worldBuilder,
            configuration: configuration,
            inputBaseline: inputBaseline,
            sessionID: SimulationSessionID()
        )
    }
}
```

The builder, Simulation behavior policy, and optional Input baseline remain
explicit. Only the new session identity is supplied locally, and the
convenience initializer delegates instead of duplicating authoritative setup.

A commonly used backing store or handler can fit the same pattern only when
each object may independently own or select another implementation. If the
store or handler must be shared consistently, keep it explicitly injected.

Structures and enumerations do not have convenience initializers. They may
define additional initializers and delegate with `self.init`, but those remain
ordinary initializers. Do not imitate class convenience-initializer syntax with
a static factory.

Do not use a convenience initializer to hide sensitivity, tick duration, or
another value that should remain consistent across instances:

```swift
extension SimulationRuntime {
    // Avoid: this hypothetical overload silently selects Game Content policy.
    convenience init(
        worldBuilder: any PWorldBuilder,
        inputBaseline: InputSnapshot?
    ) {
        self.init(
            worldBuilder: worldBuilder,
            configuration: .basicGame,
            inputBaseline: inputBaseline
        )
    }
}
```

Camera sensitivities and orbit constraints belong to the required
`SimulationConfiguration`. Omitting that value from a call site makes
inconsistent construction easy, regardless of whether the omission uses
default arguments or a real convenience initializer.

The Swift Book's `RecipeIngredient` example follows the same shape: callers
still provide the ingredient's name, while a convenience initializer supplies
the common per-instance quantity.

See
[Designated and Convenience Initializers in Action](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/initialization/#Designated-and-Convenience-Initializers-in-Action)
for Swift's class-initializer delegation rules.

## Use a Named Static Value for a Distinguished Value

Sometimes a type has a complete value worth naming: `.zero`, `.identity`,
`.one`, or `.everything`. This is not another initialization path. The member
names a notable value that callers may deliberately select.

`RenderAssetCatalog` supports caller-selected catalogs through its full
initializer, but Basic Game Content also has one meaningful complete catalog:
every model and material it declares.

Define that catalog as an immutable named value:

```swift
struct RenderAssetCatalog {
    /// Complete catalog for every asset declared by Basic Game Content.
    ///
    /// Callers may still construct a curated catalog with
    /// `init(models:materials:)`.
    static let everything = Self(
        models: [
            .ball: ModelAssetReference(
                resourceName: "Ball",
                format: .usdz
            )
        ],
        materials: [
            .warmDielectricSmooth: PBRMaterialDescription(
                baseColor: SIMD3<Float>(0.5, 0.25, 0.125),
                metallic: 0,
                perceptualRoughness: 0.2
            ),
            .warmDielectric: PBRMaterialDescription(
                baseColor: SIMD3<Float>(0.5, 0.25, 0.125),
                metallic: 0,
                perceptualRoughness: 0.5
            ),
            .warmDielectricRough: PBRMaterialDescription(
                baseColor: SIMD3<Float>(0.5, 0.25, 0.125),
                metallic: 0,
                perceptualRoughness: 0.8
            ),
            .goldMetalSmooth: PBRMaterialDescription(
                baseColor: SIMD3<Float>(1, 0.766, 0.336),
                metallic: 1,
                perceptualRoughness: 0.2
            ),
            .goldMetal: PBRMaterialDescription(
                baseColor: SIMD3<Float>(1, 0.766, 0.336),
                metallic: 1,
                perceptualRoughness: 0.35
            ),
            .goldMetalRough: PBRMaterialDescription(
                baseColor: SIMD3<Float>(1, 0.766, 0.336),
                metallic: 1,
                perceptualRoughness: 0.8
            )
        ]
    )
}
```

Basic Game Content can then make its deliberate selection visible:

```swift
self.renderAssetCatalog = .everything
```

This centralizes the definition of "everything" without making it an invisible
initializer choice. Prefer `static let` when the value is stable, immutable,
and reusable.

The declaration belongs in `RenderAssetCatalog.swift`, with the repository type
that exposes it. Never put an extension of `RenderAssetCatalog` in
`BasicGameContent.swift`: a file named for one type must not quietly contain
members of another type. A single named static value also does not justify a
standalone `RenderAssetCatalog+BasicGameContent.swift` file.

The name must remain truthful. If optional asset packs or runtime-discovered
content make "everything" contextual, use a narrower name such as `.core` or
construct the catalog explicitly. A named value is not an asset-discovery
mechanism.

## Use a Static Function for a Genuine Process

Do not wrap a straightforward synchronous initializer in a static factory
merely to hide arguments, provide defaults, or make construction look more
descriptive.

```swift
extension SInputMapping {
    /// Test-only camera binding with fixed values chosen for deterministic
    /// fixture setup. Production composition must inject shared configuration.
    static func testFixture() -> Self {
        Self(pointerOrbitSensitivity: 0.01, scrollZoomSensitivity: 0.04)
    }
}
```

This is an ordinary type method that returns a newly initialized value, not a
Swift convenience initializer. The wrapper is harmful because it:

- disguises behavior-affecting initializer arguments;
- introduces another construction API without adding construction semantics;
- makes call sites look intentionally configured when they actually select
  hidden values;
- encourages ad hoc factories for previews, tests, and production;
- uses a method where Swift's initializer syntax already expresses the work.

Prefer explicit construction:

```swift
let inputMapping = SInputMapping(pointerOrbitSensitivity: 0.01, scrollZoomSensitivity: 0.04)
```

Keep fixture construction in the fixture setup so the selected values remain
visible. If several tests share the same setup, centralize the configuration
data or the complete fixture at the appropriate test-suite boundary instead of
adding a production type method that conceals policy.

A static factory is appropriate only when it communicates semantics that an
initializer or value cannot honestly express, such as loading, decoding,
returning a cached instance, asynchronous work, choosing a concrete
implementation behind an abstract result, or performing another distinct
construction process. Document that reason; do not use a factory as an
initializer alias.

```swift
let models = try USDRenderModel.load(catalog: renderAssetCatalog, device: device)
```

Do not spell a fixed distinguished value as a function:

```swift
// Avoid: parentheses imply a process even though this selects one fixed value.
let catalog = RenderAssetCatalog.everything()
```

Use `static let everything` for that case.

## Keep Default Arguments Exceptional

Default argument values should be rare. Make the caller provide values that
affect simulation, timing, physics, input response, limits, persistence, or
other application behavior.

A default argument makes a choice when the caller says nothing. Use one only
when omission is independently safe, incidental to the type's meaning, and
strongly justified in the declaration's documentation. Do not add one merely
to shorten call sites or preserve source compatibility.

Do not use a default argument to select a distinguished value:

```swift
// Avoid: selecting every asset is now implicit.
init(renderAssetCatalog: RenderAssetCatalog = .everything) {
    self.renderAssetCatalog = renderAssetCatalog
}
```

Requiring `.everything` at the call site keeps the semantic choice explicit.

The rule is even more important for values that must remain consistent across
objects or subsystems. Injection establishes one deliberate source of
configuration. Adding defaults to the injected initializer weakens that
boundary: one caller can accidentally omit a value, silently select local
policy, and behave differently from the rest of the application.

```swift
// Avoid: these defaults can silently create inconsistent input behavior.
struct SInputMapping {
    let pointerOrbitSensitivity: Float
    let scrollZoomSensitivity: Float

    init(pointerOrbitSensitivity: Float = 0.01, scrollZoomSensitivity: Float = 0.04) {
        self.pointerOrbitSensitivity = pointerOrbitSensitivity
        self.scrollZoomSensitivity = scrollZoomSensitivity
    }
}
```

The defaults make construction convenient, but they also make it easy for one
call site to forget the shared configuration. Sensitivity affects observable
Simulation behavior, so every production construction path should receive the
same deliberately selected values.

Require the composition root to provide coordinated values:

```swift
let inputMapping = SInputMapping(
    pointerOrbitSensitivity: simulationConfiguration.pointerOrbitSensitivity,
    scrollZoomSensitivity: simulationConfiguration.scrollZoomSensitivity
)
```

This makes the dependency visible and requires the composition root to select
the policy. Missing configuration becomes a compile-time error instead of a
silent behavioral difference. Keep values such as these explicit:

- fixed tick duration;
- movement, rotation, or camera sensitivity;
- physics constants and tolerances;
- retry, timeout, and buffering limits;
- retention and resource budgets;
- persistence and storage policy;
- encoding or quality policy.

A convenience initializer is not an exemption from configuration consistency.
Ask whether each instance may safely choose the omitted value independently. If
the value must agree across objects or subsystems, inject it explicitly from
shared configuration.

Prefer a class convenience initializer for a coherent secondary initialization
path, a named static value for a distinguished value, and injected shared
configuration for coordinated policy.
