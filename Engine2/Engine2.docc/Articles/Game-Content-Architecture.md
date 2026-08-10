# Game Content Architecture

This article defines the proposed boundary between reusable Engine2 machinery and the game-specific content supplied by an engine consumer.

## Status

Proposed direction.

The current project still compiles engine code, example entities, world construction, rendering assets, and the application into one target. The types and construction examples in this article describe the boundary Engine2 should grow toward; they are not all implemented APIs.

## Game Content Is Not a Runtime

**Game Content** is the immutable or declarative game-specific material used to construct and configure runtimes.

Game Content can include:

- concrete entity types and typed entity facades
- game-specific components and behavior descriptions
- world builders and initial scenarios
- render descriptions such as mesh and material identities
- audio descriptions and mappings from game events to sounds
- models, textures, sounds, animation data, levels, and other assets
- catalogs that connect stable asset identities to packaged asset sources

Game Content does not have its own cadence or autonomous lifecycle. It does not tick, render, collect input, or perform background work merely by existing. An App-owned Runtime Assembly supplies Game Content to the runtimes it constructs, and each runtime converts the relevant content into its own private operational state.

This distinction keeps the top-level model clear:

```text
Engine2                reusable runtime and ECS machinery
Game Content           consumer-defined game code, descriptions, and assets
App                    selects Game Content and one Runtime Assembly,
                       then injects the selected content
Runtime Assembly       constructs, connects, and presents one runtime graph
Runtime                long-lived owner that executes using supplied content
```

## Assets Are Not ECS Resources

Use **Asset** for source content shipped by a game, even though Swift Package Manager uses the term `resource` for bundled files.

Use **Resource** for long-lived mutable state owned by a runtime or world.

For example:

| Kind | Example | Owner |
| --- | --- | --- |
| Asset | `spaceship.usdz`, `laser.wav`, a texture, or a level file | Game Content |
| Asset identity | `MeshID.spaceship` or `SoundID.laser` | Game Content |
| ECS resource | camera state or simulation configuration | Simulation Runtime or `World` |
| Runtime resource | `MTKMesh`, `MTLBuffer`, decoded audio, or a pipeline cache | Render or Audio Runtime |

An asset is input to runtime construction or loading. A runtime resource is the runtime-owned operational representation produced from that asset.

## Content Uses Backend-Neutral Identities

Game Content should describe presentation using strongly typed, backend-neutral identities rather than Metal or audio-framework objects.

A game's content can own exhaustive identities such as:

```swift
enum MeshID: Hashable, Sendable {
    case spaceship
}

enum MaterialID: Hashable, Sendable {
    case playerShip
}

enum SoundID: Hashable, Sendable {
    case engineLoop
    case laser
}
```

Each asset category uses its own Game Content-owned enum. The Simulation and
presentation runtimes may carry and resolve these immutable values, but Game
Content owns the vocabulary because it defines the entities and assets that
exist in the game. Do not replace a closed identity set with untyped `String`
or `Int` values.

## Entities Carry Abstract Presentation Intent

Consumer-defined entities should remain ergonomic typed facades over authoritative ECS state. Their presentation components contain stable asset identities and abstract presentation state, not loaded backend objects.

The current render component and a possible continuous-audio component
illustrate that split:

```swift
struct CRenderable: PComponent {
    var meshID: MeshID
    var materialID: MaterialID
}

struct CAudioEmitter: PComponent {
    var sound: SoundID
    var playback: AudioPlaybackState
}
```

The Simulation Runtime owns these component rows because they are authoritative abstract game state. A publisher-owned `SimulationPresentationSnapshot` carries completed abstract presentation state across the runtime boundary. The Render Runtime can project that source state into a private render-oriented value such as:

```swift
struct RenderInstance {
    let transform: Transform
    let meshID: MeshID
    let materialID: MaterialID
}
```

The Render Runtime owns that projection and resolves `MeshID` and `MaterialID` through the render assets supplied by Game Content. It privately owns the resulting meshes, textures, buffers, and pipelines.

```text
Game Content asset
        |
        v
Stable asset identity in ECS
        |
        v
Publisher-owned SimulationPresentationSnapshot
        |
        v
Render-owned projection
        |
        v
Runtime-owned backend resource
```

## Continuous State and Ephemeral Presentation Differ

Continuous presentation belongs naturally in state and snapshots. Examples include:

- which mesh and material currently represent an entity
- which looping sound an emitter currently uses
- listener position and orientation
- music or ambient context

Ephemeral occurrences may begin as Simulation Runtime events. For example, the Simulation Runtime can publish that a weapon fired without naming an Audio Runtime or a sound file.

Game Content can supply the presentation rule that gives the event a particular sound:

```text
Simulation Runtime event:        a weapon fired
Game Content rule:         this weapon uses SoundID.laser
Audio Runtime behavior:    resolve and play the matching asset
```

This keeps gameplay semantic, presentation game-specific, and backend execution runtime-owned.

A snapshot-only consumer needs any visible occurrence represented in durable snapshot state. Render does not consume simulation events, so a muzzle flash, explosion, or similar effect needs snapshot-visible identity and lifetime long enough for Render to observe it even when intermediate simulation snapshots are skipped.

## Runtime Assemblies Construct Runtimes From Game Content

The App selects one ``PRuntimeAssembly`` implementation at compile time and retains the constructed value behind an opaque `some PRuntimeAssembly` property. The assembly is the concrete composition object for that topology: its required `init(gameContent:)` constructs the independently owned runtimes and supplies each relevant portion of the injected content. Explicit assembly initializers take focused policy, limit, and identity values directly for tests, tools, and specialized hosts.

The example App constructs `BasicGameContent` and passes it to the selected
assembly. `BasicGameContent.init()` now supplies
`TerrestrialPlanetWorldBuilder` to ``SimulationRuntime`` beside the complete
`.basicGame` ``SimulationConfiguration``, and deliberately selects
`RenderAssetCatalog.everything` for the current render paths. Its explicit
`init(worldBuilder:)` keeps world construction injectable without hiding either
behavior or catalog policy behind a default argument. Callers may still
construct curated catalogs through
`RenderAssetCatalog.init(models:materials:terrestrialPlanets:textures:)`. The
named `.basicGame` and `.everything` values remain in
`SimulationConfiguration.swift` and `RenderAssetCatalog.swift`, respectively.
Repository-owned types are extended only from their own files;
`BasicGameContent.swift` selects those values without quietly declaring members
of either type.

``TerrestrialPlanet`` advertises one backend-neutral
`MeshID.terrestrialPlanet` and `MaterialID.terrestrialPlanet` beside one
Simulation-owned transform. Game Content maps the mesh and four texture
identities to exact source URLs, gives every texture an explicit sRGB or linear
interpretation, and supplies one ``TerrestrialPlanetDescription``. Render
privately resolves those descriptions into the decoded mesh, textures,
pipelines, argument-table bindings, and three ordered layer draws. ``World`` and
the entity contain no filename, material factor, decoded pixel, or Metal object.
See <doc:Terrestrial-Planet-Proof>.

`BasicWorldBuilder` remains the deterministic six-sphere PBR fixture. Every
fixture entity shares `MeshID.ball`, while its `MaterialID` selects one smooth,
baseline, or rough warm dielectric or gold-metal description. A caller can
inject that builder explicitly, but `BasicGameContent.init()` now selects the
single-planet proof scene by default. Neither scene adds a renderer object or
light state to Simulation.

A consumer assembly may use the same production-plus-injection shape:

```swift
struct MyGameAssembly: PRuntimeAssembly {
    var body: some View {
        MyGameAssemblyView(assembly: self)
            .onAppear {
                self.startVisibilityDependentWork()
            }
            .onDisappear {
                self.stopVisibilityDependentWork()
            }
    }

    init(gameContent: any PGameContent) {
        self.init(
            gameContent: gameContent,
            sessionID: SimulationSessionID()
        )
    }

    init(
        gameContent: any PGameContent,
        sessionID: SimulationSessionID
    ) {
        // Construct the complete runtime graph and retain its connections.
    }

    private func startVisibilityDependentWork() {
        // Start visibility-dependent work in dependency order.
    }

    private func stopVisibilityDependentWork() {
        // Stop visibility-dependent work in reverse dependency order.
    }
}
```

``PRuntimeAssembly`` refines SwiftUI `View`. `View` supplies an associated `Body` type and the `body` requirement, so each concrete assembly can satisfy that inherited requirement with `some View`. The opaque result resolves to one concrete body type for that conformer. An App can retain its compile-time-selected assembly behind `some PRuntimeAssembly`; the opaque property hides the underlying type from the surrounding App surface while preserving it for the compiler and SwiftUI. Runtime-dynamic selection among heterogeneous assemblies would instead require an explicit enum or type-erasing host.

A Runtime Assembly is a value-type View because SwiftUI requires custom views to use value semantics. Its stored Runtime, driver, coordinator, and focused mutable-state references preserve one live graph when SwiftUI copies the assembly value. Calling an assembly initializer constructs a new graph; copying an existing assembly does not.

A nonthrowing Game Content initializer such as this one satisfies the protocol's throwing initializer requirement. If construction can fail, the selecting App must choose an explicit launch policy; the common protocol does not manufacture fallback UI.

SwiftUI appearance modifiers belong inside the body of an assembly that owns visibility-dependent work. Assemblies without that work add no lifecycle surface. View disappearance is not a common terminal-shutdown requirement. In particular, ordinary disappearance of an ``AgentSessionAssembly`` does not close the session; its explicit host still calls `stopAndDrain()` when that live session ends.

`PGameContent` is the narrow assembly-construction substitution seam shared by the implemented topologies. It contains exactly three construction values: ``PWorldBuilder``, ``SimulationConfiguration``, and ``RenderAssetCatalog``. It does not expose live runtimes, lifecycle operations, cadence, storage, or a topology-specific capability bag. A consumer may conform with one immutable composition value while retaining its own supporting namespaces and focused catalogs.

The important ownership rules are:

- Game Content does not start or stop runtimes.
- Runtimes do not discover Game Content through global state.
- Runtimes receive only the content relevant to their responsibility.
- A runtime may transform content into private caches or backend resources.
- Game Content remains reusable across runtime reconstruction and new game sessions when practical.

The runtime that performs work owns the construction interfaces it consumes. Simulation therefore owns ``PWorldBuilder`` because it defines what is required to construct a valid ``World``. Runtime publications follow a complementary ownership rule: a publisher owns the snapshot and event vocabulary describing its authority, while a consumer owns the projections and private operational models it derives. Simulation owns `SimulationPresentationSnapshot`; Render owns its transformation into a private render snapshot. Game Content supplies conforming values and descriptions without owning runtime protocols, publication schemas, or invariant scheduling. See <doc:Runtime-Communication>.

## Game Content Is a Natural Consumer Module

The Engine2 package should provide reusable runtime contracts and implementations. A consumer can place its Game Content in an application target, a local SwiftPM target, or a separately distributed package.

A likely dependency shape is:

```text
MyGameContent -------> Engine2Core
Engine2Metal --------> Engine2Core
Engine2Audio --------> Engine2Core
Engine2AppKitInput --> Engine2Core

MyGameApp -----------> MyGameContent
MyGameApp -----------> Engine2Metal
MyGameApp -----------> Engine2Audio
MyGameApp -----------> Engine2AppKitInput
```

`MyGameContent` depends on public Engine2 contracts but not on concrete Metal, AppKit, or audio backend implementations. The App selects the assembly type; that assembly selects runtime implementations and supplies the consumer's content to them.

Do not make every Runtime a separate Swift package by default. Runtime boundaries describe ownership and lifecycle. SwiftPM targets describe compilation modules, and packages describe distribution and versioning. One Engine2 package can vend a core product plus optional platform-runtime products.

## Required Public Extension Surface

For Engine2 to serve as a base engine, consumers will eventually need supported public APIs to:

1. define component types
2. define optional behaviors through controlled Simulation Runtime extension points
3. define typed entity facades
4. spawn entities and seed component rows
5. construct worlds and sessions
6. attach abstract render and audio descriptions
7. supply strongly typed asset catalogs
8. provide presentation rules for relevant game events
9. construct runtimes without importing the example application

Do not respond by making every current type public. The package should expose the smallest coherent extension surface while keeping storage, scheduler, and backend implementation details internal where possible.

The Simulation Runtime owns and schedules invariant systems required for valid position, orientation, input, and other core mechanics. A future behavior extension must compose with that schedule; it must not move the simulation foundation into Game Content.

The current ``World`` has a fixed list of component stores, and ``World/add(_:from:renderable:)`` translates a fixed list of capability protocols. That is appropriate for the current experiment but is the largest structural limitation on external Game Content. Before claiming general consumer-defined components, Engine2 needs a strongly typed extension path for externally defined component storage, spawning, and system access without returning to a closed component enum or a global registry.

## Current-to-Proposed Mapping

Current project elements map onto Game Content as follows:

| Current element | Emerging ownership |
| --- | --- |
| ``Ball`` | Example Game Content entity facade |
| ``TerrestrialPlanet`` | Example Game Content entity facade whose one abstract render identity expands privately into layered Render work |
| ``BasicWorldBuilder`` | Retained deterministic six-sphere PBR fixture |
| `TerrestrialPlanetWorldBuilder` | Default example world construction containing one authoritative planet entity |
| `Ball.usdz` and `Ball.usda` | Example render assets owned by Game Content and resolved privately by the current render path |
| `TerrestrialPlanet.usdz`, four planet maps, and their manifest | Deterministically generated example assets owned by Game Content |
| `BasicGameContent` | Example assembly-selected composition that defaults to the planet world while retaining injectable world construction |
| `MeshID` | Game Content-owned, backend-neutral mesh identity enum |
| `MaterialID` | Game Content-owned, backend-neutral authored material identity enum |
| `TextureID` | Game Content-owned, backend-neutral texture identity enum |
| `PBRMaterialDescription` | Render-owned, backend-neutral material contract populated by Game Content |
| `TerrestrialPlanetDescription` | Render-owned, backend-neutral layered-material contract populated by Game Content |
| `TextureAssetReference` | Exact source URL and typed transfer-function interpretation selected by Game Content |
| `RenderAssetCatalog` | Render-owned catalog input contract populated by Game Content |
| `ModelShaders.metal` and `TerrestrialPlanetShaders.metal` | Render Runtime backend implementation unless a future public material/shader extension point deliberately makes it content |
| Debug panes and app commands | Example App tooling, not reusable Game Content or runtime core |

The first extraction should move example content out of reusable engine targets without forcing immediate redesign of every ECS API. The example application can continue to prove the public construction path as those APIs become deliberate.

## Related Direction

- <doc:Runtime-Communication>
- <doc:Runtime-Architecture>
- <doc:Runtime-Assemblies-and-Advancement>
- <doc:Engine-Architecture>
- <doc:Rendering-Architecture>
- <doc:Resource-Ownership-and-Presentation-Boundaries>
