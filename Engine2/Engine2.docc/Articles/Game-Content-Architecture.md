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

Game Content does not have its own cadence or autonomous lifecycle. It does not tick, render, collect input, or perform background work merely by existing. The App uses Game Content to construct runtimes, and each runtime converts the relevant content into its own private operational state.

This distinction keeps the top-level model clear:

```text
Engine2                reusable runtime and ECS machinery
Game Content           consumer-defined game code, descriptions, and assets
App                    composition root that constructs and connects runtimes
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

## The App Constructs Runtimes From Game Content

The App is the composition root. It creates one game-content value, then supplies the relevant portions to independently constructed runtimes.

The example app now implements the first version of this boundary with
`BasicGameContent`. It supplies `BasicWorldBuilder` to ``SimulationRuntime``
and a `RenderAssetCatalog` to the current render path. ``Ball`` advertises only
the backend-neutral `MeshID.ball` plus a `MaterialID`; Game Content maps the mesh
to `Ball.usdz` and maps each material identity to a `PBRMaterialDescription`.
The renderer privately turns those descriptions and packaged source assets into
per-draw data, Model I/O values, and Metal resources. Neither ``World`` nor
``Ball`` contains a filename, material factor, or backend object.

`BasicWorldBuilder` currently uses that boundary to construct a deterministic
six-sphere material grid. Every entity shares `MeshID.ball`, while its
`MaterialID` selects one smooth, baseline, or rough warm dielectric or gold
metal description. The scene adds no renderer object or light state to Game
Content or Simulation.

A future construction shape may resemble:

```swift
let content = MyGameContent()

let inputRuntime = InputRuntime()

let simulationRuntime = SimulationRuntime(
    worldBuilder: content.worldBuilder
)

let renderRuntime = RenderRuntime(
    assets: content.renderAssets
)

let audioRuntime = AudioRuntime(
    assets: content.audioAssets,
    presentation: content.audioPresentation
)
```

This example is intentionally concrete rather than a requirement for one large `PGameContent` protocol. A game-content type may be a simple immutable composition value, namespace, or set of focused catalogs. Introduce protocols only where multiple implementations or substitution create real value.

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

`MyGameContent` depends on public Engine2 contracts but not on concrete Metal, AppKit, or audio backend implementations. The App selects the runtime implementations and supplies the consumer's content to them.

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

The current ``World`` has a fixed list of component stores, and ``World/add(_:from:)`` translates a fixed list of capability protocols. That is appropriate for the current experiment but is the largest structural limitation on external Game Content. Before claiming general consumer-defined components, Engine2 needs a strongly typed extension path for externally defined component storage, spawning, and system access without returning to a closed component enum or a global registry.

## Current-to-Proposed Mapping

Current project elements map onto Game Content as follows:

| Current element | Emerging ownership |
| --- | --- |
| ``Ball`` | Example Game Content entity facade |
| ``BasicWorldBuilder`` | Example Game Content world construction |
| `Ball.usdz` and `Ball.usda` | Example render assets owned by Game Content and resolved privately by the current render path |
| `BasicGameContent` | Example App-supplied composition of world construction and render asset mappings |
| `MeshID` | Game Content-owned, backend-neutral mesh identity enum |
| `MaterialID` | Game Content-owned, backend-neutral authored material identity enum |
| `PBRMaterialDescription` | Render-owned, backend-neutral material contract populated by Game Content |
| `RenderAssetCatalog` | Render-owned catalog input contract populated by Game Content |
| `ModelShaders.metal` | Render Runtime backend implementation unless a future public material/shader extension point deliberately makes it content |
| Debug panes and app commands | Example App tooling, not reusable Game Content or runtime core |

The first extraction should move example content out of reusable engine targets without forcing immediate redesign of every ECS API. The example application can continue to prove the public construction path as those APIs become deliberate.

## Related Direction

- <doc:Runtime-Communication>
- <doc:Runtime-Architecture>
- <doc:Engine-Architecture>
- <doc:Rendering-Architecture>
- <doc:Resource-Ownership-and-Presentation-Boundaries>
