# Game Content Architecture

Game Content separates game-specific construction and assets from Runtime
ownership. This article documents the implemented in-target seam and the public
consumer boundary that remains proposed.

## Status

Partially implemented. ``GameContent`` supplies Input mapping, controlled
Simulation behavior, world construction, Simulation configuration, and a Render
asset catalog to the current ``RealtimeAssembly``. Engine code, example content,
assets, and the App still compile into one application target. None of these
contracts is currently a supported public API for an external consumer module.

Audio content, Simulation event-presentation rules, separate engine products,
and general consumer-defined component storage remain proposed.

## Game Content Is Not a Runtime

**Game Content** is consumer-defined code, descriptions, catalogs, and packaged
assets used to construct and configure runtimes.

Game Content can include:

- concrete entity types and typed entity facades
- physical input bindings and context-free semantic mapping policy
- game-specific components and behavior descriptions
- world builders and initial scenarios
- render descriptions such as mesh and material identities
- audio descriptions and mappings from game events to sounds
- models, textures, sounds, animation data, levels, and other assets
- catalogs that connect stable asset identities to packaged asset sources

Game Content has no cadence or autonomous lifecycle. It does not tick, render,
collect input, or perform background work merely by existing. The App supplies
it to a Runtime Assembly, which uses the relevant values while constructing its
topology.

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

Use **Asset** for source content shipped by a game, even though Swift Package
Manager uses the term `resource` for bundled files.

Use **Resource** for long-lived mutable state owned by a runtime or world.

For example:

| Kind | Example | Owner |
| --- | --- | --- |
| Asset | `spaceship.usdz`, `laser.wav`, a texture, or a level file | Game Content |
| Asset identity | `MeshID.spaceship` or `SoundID.laser` | Game Content |
| World resource | camera state or ``InputState`` | ``World`` |
| Runtime resource | `MTKMesh`, `MTLBuffer`, decoded audio, or a pipeline cache | Render or Audio Runtime |

An asset is input to Runtime construction or loading. A Runtime resource is the
operational representation produced from that asset.

## Content Uses Backend-Neutral Identities

Game Content describes presentation with strongly typed, backend-neutral
identities rather than Metal or audio-framework objects. The current project
implements ``MeshID`` and ``MaterialID`` as exhaustive enums. A future audio
surface should use a separate identity type such as `SoundID`.

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

Each closed asset category uses its own Game Content-owned enum. Simulation may
carry these immutable values, and the responsible presentation path may resolve
them, but Game Content owns the vocabulary because it defines the entities and
assets in the game. Do not replace a closed identity set with untyped `String`
or `Int` values.

## Entities Carry Abstract Presentation Intent

Consumer-defined entities inherit identity and lifecycle visibility from ``Entity`` and
provide typed facades over component-owned gameplay values. Their presentation
components contain stable asset identities and
abstract presentation state, not loaded backend objects.

The current render component and a possible continuous-audio component
illustrate that split:

```swift
struct RenderableComponent: Component {
    var meshID: MeshID
    var materialID: MaterialID
}

struct AudioEmitterComponent: Component {
    var sound: SoundID
    var playback: AudioPlaybackState
}
```

The Simulation Runtime owns the current ``RenderableComponent`` rows because
they are authoritative abstract game state. A future audio component belongs
there only when it represents authoritative continuous state.
``SimulationPresentationSnapshot`` carries completed presentation facts across
the Runtime boundary. The current screen path projects that value through
``RenderFrame`` into ``RenderInstance`` values, then resolves ``MeshID`` and
``MaterialID`` through the catalog supplied by Game Content. Render privately
owns the resulting meshes, textures, buffers, and pipelines.

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

## Snapshots Carry Continuous State

Continuous presentation belongs naturally in state and snapshots. The current
snapshot carries entity mesh and material identities plus the camera. Future
audio state might similarly include a looping emitter, listener transform, or
ambient context.

The current Render path is snapshot-only and may skip superseded Simulation
publications. A visible occurrence such as a muzzle flash or explosion must
therefore remain in snapshot state long enough for Render to observe it or
converge past it correctly.

## Proposed Event-Presentation Rules

General Simulation event publication and an Audio Runtime are not implemented.
A future Simulation Runtime may publish a semantic event such as a weapon firing
without naming a sound asset or Audio Runtime.

Game Content can supply the presentation rule that gives the event a particular sound:

```text
Simulation Runtime event:        a weapon fired
Game Content rule:         this weapon uses SoundID.laser
Audio Runtime behavior:    resolve and play the matching asset
```

This proposed split would keep gameplay semantic, presentation rules
game-specific, and backend execution Runtime-owned. Any event lane still needs
explicit ordering, retention, and consumer-position semantics. See
<doc:Runtime-Communication>.

## Runtime Assemblies Construct Runtimes From Game Content

The App selects one ``RuntimeAssembly`` implementation at compile time and
retains the constructed value behind `some RuntimeAssembly`. The required
``RuntimeAssembly/init(using:)`` initializer receives Game Content and constructs
the topology. A concrete assembly may also expose direct initializers for its
focused policy. See <doc:Runtime-Assemblies-and-Advancement> for assembly
ownership and lifecycle.

``GameContent`` is the five-value construction seam consumed by the current
``RealtimeAssembly``:

- ``InputMappingConfiguration``
- ``SimulationBehavior``
- ``WorldBuilder``
- ``SimulationConfiguration``
- ``RenderAssetCatalog``

`RealtimeAssembly` constructs ``InputRuntime`` from the mapping policy and
``SimulationRuntime`` from the builder, Simulation configuration, and behavior.
It retains the Render catalog for the screen path. ``GameContent`` exposes no
live Runtime, lifecycle operation, cadence, storage, or topology-specific
capability bag.

The Runtime that performs work owns the interface it consumes. Simulation owns
``WorldBuilder``; Game Content supplies a conforming recipe. Simulation owns
``SimulationPresentationSnapshot``; Render owns ``RenderFrame`` and the private
resources derived from it. Game Content supplies values without owning Runtime
protocols, publication schemas, or invariant scheduling.

## Basic Example Content

``BasicGameContent`` selects `.basicGame` Input and Simulation configuration,
``StandardSimulationBehavior``, ``BasicWorldBuilder``, and
`RenderAssetCatalog.everything`. Its `init(worldBuilder:)` keeps world
construction injectable while retaining the other authored choices.

For presentation, ``Ball`` registers `MeshID.ball` and one ``MaterialID``.
`RenderAssetCatalog.everything` maps that mesh to `Ball.usdz` and maps every
material identity to a ``PBRMaterialDescription``. Render privately converts
those descriptions and the packaged model into backend resources. Neither
``World`` nor ``Ball`` contains a filename, material factor, or Metal object.

``BasicWorldBuilder`` constructs a deterministic six-ball material grid. Every
entity shares `MeshID.ball`; material identity selects a smooth, baseline, or
rough warm dielectric or gold metal. Neutral motion and rotation seeds keep the
scene quiescent through the ordinary Simulation schedule.

## The Mining Slice Is Composed Game Content

The mining slice uses the same seam for one star, six asteroids, one player
skiff, and one depot. Game Content defines entity facades, authored spawn facts,
mapping policy, behavior, and abstract render identities. Each entity has a
designated initializer with the authored values it needs, such as mass, ore,
collision radius, thrust, and missile speed. The constructor assembles one
flat `Entity.InitialState` and calls `super.init(in:from:)`. The base Entity
initializer reserves the identity and calls ``World/add(_:from:)``.
World delegates to ``Components``, which iterates its metatype list. Component
initializers validate capability agreement and initialize authored, derived,
and transient state before registration returns.
Simulation owns the resulting rows and all later gameplay mutation.

Asteroid and depot constructors supply the primary's complete identity,
orbital radius, angular speed, and phase directly in `Entity.InitialState`.
The component initialization order resolves the primary's live position and
creates the rail, position, and collision history before dependent rows are used. Constructors do not receive a
duplicate primary position or build a rail component. The world is ready for
its tick-zero presentation without running a setup system.

``MiningWorldBuilder`` owns the gravitational parameter, orbital radii, derived
circular speeds, and initial camera framing. ``OrbitalRailSystem`` remains a
Simulation-owned policy supplied at a Game Content scheduling stage; Runtime
cadence does not define scenario scale or orbital speed.

The mining ``InputMappingConfiguration`` maps keyboard and pointer input to
context-free translation, interaction, fire, camera, and selection intent. It
cannot name the skiff or inspect selection. A fire press requests an action;
Simulation chooses the launcher, target, and resulting missile. ``Interactable`` owns the shared positioned
proximity range; ``Mineable`` and ``DepotServicing`` add action-specific state
and rates.

``MiningSimulationBehavior`` supplies selection and control routing, circular
rails, gravity and propulsion, missile launch, contact effects, expiry, collision response,
mining and depot service, camera follow, and orbit assistance at fixed ``SimulationSystemSchedule``
stages. The orbit-assist command arrives on an exact Simulation request rather
than through physical input mapping. See <doc:System-Scheduling> for the exact
system order.

This is a mixed-dynamics scenario. Surviving asteroids and the depot follow
analytic circular rails. The skiff dynamically integrates gravity, propulsion,
fuel, cargo-dependent mass, and collision response. Its missiles integrate
ballistic motion until impact or expiry.

``Missile`` is a Game Content recipe that composes ``Ownable``, ``Expirable``,
``ContactDamaging``, and ``ContactConsumable`` with movement, collision, scale, and rendering.
``OwnershipComponent`` and ``LifetimeComponent`` are reusable independent state;
outgoing damage and source consumption also have separate component rows.
The missile authors sensor collision response, owner exclusion, and one point
of contact damage. ``Asteroid`` independently supplies ``Damageable`` health.
The depot and star remain solid obstacles without health, so missiles are
consumed by them without removing them.

Every entity inherits the standalone ``Destructible`` capability from ``Entity``
and receives an ``DestructibleComponent`` on registration. The capability exposes
read-only lifecycle state. The generic contact-effect and lifetime systems request
deferred removal by setting the lifecycle component to `pendingRemoval`. Other
entity types can reuse damage, consumption, collision, ownership, and lifetime
independently. ``MissileLaunchSystem`` lives in Game Content and retains the
missile construction recipe and nearest active ore-deposit targeting policy.
Targetability is separate from health and removal.

The selected-entity inspector renders only capabilities supported by the live
facade obtained from a narrow, read-only Simulation-owned source. A separate
callback submits the displayed entity's complete identity for orbit assistance.
It does not make the facade mutable, route inspection through
``SimulationPresentationSnapshot``, or add renderer-specific state to ECS.

## Proposed Consumer Module Boundary

The current Xcode project has one application target, so the `Game Content`
directory expresses logical ownership rather than a compiler-enforced module
boundary. A future framework or package can expose reusable Engine2 contracts
while consumer content remains independent of concrete Metal, AppKit, or audio
backend implementations.

Runtime and module boundaries answer different questions. Runtime boundaries
describe state, lifecycle, and cadence. Targets and packages describe compilation
and distribution. Engine2 does not need one package per Runtime.

## Proposed Public Extension Surface

External consumers need a coherent public API before Engine2 can claim support
for separately compiled Game Content. That surface must support:

1. Strongly typed component storage, entity facades, spawning, and system access.
2. Physical-to-semantic mappings and controlled Simulation behavior.
3. World and session construction.
4. Backend-neutral presentation descriptions and typed asset catalogs.
5. Presentation rules for any supported Simulation events.
6. Runtime construction without importing the example App.

The internal ``SimulationBehavior`` and ``SimulationSystemSchedule`` contracts
already demonstrate controlled behavior insertion, but they are not public API.
The Engine foundation remains camera input, acceleration intent, movement,
rotation, and input cleanup; consumer behavior cannot replace or reorder it.

``World`` owns one ``Components`` container with typed access such as
`world.components[PositionComponent.self]`. Its engine-owned metatype list drives
allocation, initialization, and removal. Component initializers translate
capabilities and the flat `Entity.InitialState` into rows; ``Component`` supplies
default removal through its protocol extension. General external components therefore need a strongly
typed extension path for storage, spawning, and system access. A closed
component enum or process-global registry would not provide that boundary.

## Current Logical Ownership

| Current element | Ownership |
| --- | --- |
| ``Ball`` | Example Game Content entity facade |
| ``BasicWorldBuilder`` | Example Game Content world construction |
| `Ball.usdz` | Packaged Game Content model resolved by the current Render path |
| `Ball.usda` | Game Content source asset; the current catalog resolves the USDZ form |
| ``BasicGameContent`` | Example composition of Input, Simulation, world, and Render construction values |
| ``InputMappingConfiguration`` | Input-owned mapping policy selected by Game Content |
| ``SimulationBehavior`` and ``SimulationSystemSchedule`` | Simulation-owned controlled behavior boundary populated by Game Content |
| ``MeshID`` and ``MaterialID`` | Game Content-owned backend-neutral identity enums |
| ``PBRMaterialDescription`` | Render-owned backend-neutral material contract supplied through the catalog |
| ``RenderAssetCatalog`` | Render-owned catalog input selected by Game Content |
| `ModelShaders.metal` | Render backend implementation |
| Debug panes and App commands | Example App tooling |

The existing directory split establishes the intended ownership vocabulary.
A future module extraction should expose the smallest coherent public surface
without moving backend resources into Game Content or making every internal
type public.

## Related Direction

- <doc:Runtime-Communication>
- <doc:Runtime-Architecture>
- <doc:Runtime-Assemblies-and-Advancement>
- <doc:Engine-Architecture>
- <doc:Rendering-Architecture>
- <doc:Resource-Ownership-and-Presentation-Boundaries>
