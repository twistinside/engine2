# Engine2 AGENTS Guide
## Repo Summary
Engine2 is a compact Swift ECS experiment with a small but increasingly coherent runtime shape. The project is moving toward a hybrid model:
- ECS component stores are the simulation source of truth.
- Entity objects are ergonomic, typed facades over ECS state.
- Capability protocols such as `PMovable` and `PPositionable` are kept as the game-facing/UI-facing surface.
- Systems should operate directly on component stores in hot paths.
This repo is still early, but several core paths now exist. Preserve direction and intent when filling in missing pieces.

## Runtime Architecture
The proposed top-level application architecture is documented in `Engine2/Engine2.docc/Articles/Runtime-Architecture.md`.

Use these terms consistently:
- A **Runtime** is a long-lived top-level application object with its own state, lifecycle, cadence, and explicit boundaries. Runtime types use the full `Runtime` suffix, such as `InputRuntime`, `SimulationRuntime`, and `RenderRuntime`.
- The App owns and wires runtimes. Runtimes do not discover one another through global mutable state.
- The **Simulation Runtime** is authoritative for gameplay state and contains `Engine`, `World`, ECS resources, and ECS systems. It is first among peers semantically, but it does not own the lifecycles of other runtimes.
- An ECS **System** is scheduled logic inside the Simulation Runtime, not a top-level runtime. Keep the `S` prefix reserved for systems.
- A **Snapshot** is an immutable point-in-time boundary value. Snapshot types use a descriptive `Snapshot` suffix rather than an `S` prefix.
- An **Event** is an immutable fact published within a runtime's authority. Optional peer runtimes may observe it; the publisher must remain correct when no consumer exists.
- Prefer snapshots and events for peer-runtime choreography. Directed request/result workflows should represent deliberate dependencies and normally be coordinated by the App.
- Runtimes may differ in usefulness without peers. Independence means explicit ownership and lifecycle safety, not equal standalone capability.
- There is no universal frame cadence. Input delivery, fixed Simulation Runtime ticks, render frames, and future Audio/Network/Storage work may advance independently.

Current types implement part of this direction:
- `SimulationRuntime` is the app-facing Simulation Runtime lifecycle boundary; `SimulationLoop`, `Engine`, and `World` are its internal mechanisms.
- `InputMetalView` in UI and `InputState` in Simulation currently split input collection from simulation-facing state; a future Input Runtime boundary should publish immutable input snapshots.
- `RenderFrame` is the current simulation-to-render snapshot representation; `MetalSceneView` and `MetalRenderer` cover early Render Runtime responsibilities.

Do not rename or wrap existing types solely to match the vocabulary. Introduce a runtime boundary when it creates concrete ownership, lifecycle, cadence, or testing value.

## Game Content Architecture
The proposed consumer-content boundary is documented in `Engine2/Engine2.docc/Articles/Game-Content-Architecture.md`.

Use these terms and constraints consistently:
- **Game Content** is consumer-defined game code, descriptions, catalogs, and assets used to construct and configure runtimes. It is not a runtime and has no independent cadence or lifecycle.
- The App is the composition root. It constructs Game Content, then supplies the relevant portions to independently constructed runtimes.
- Use **Asset** for packaged source content such as models, textures, sounds, animations, and levels. Do not conflate assets with ECS or runtime resources, even though SwiftPM calls bundled files resources.
- Content refers to assets through strongly typed, backend-neutral identities such as the current `MeshID` and future `MaterialID` and `SoundID` values. Do not store raw `MTLBuffer`, `MTKMesh`, decoded audio, or other backend objects in ECS or Game Content.
- Runtimes privately resolve content assets into backend resources. Game Content does not own runtime caches, GPU allocations, decoded audio, or runtime lifecycle.
- Continuous presentation can be described through abstract ECS state and snapshots. Ephemeral presentation should normally derive from Simulation Runtime events plus consumer-supplied presentation rules.
- Consumer Game Content may eventually define entities, components, optional behaviors, world builders, render/audio descriptions, asset catalogs, and event-presentation mappings through deliberate public Engine2 APIs.
- The Simulation Runtime owns invariant systems and their foundational schedule. Future Game Content behavior must enter through controlled extension points rather than replacing that foundation.
- The runtime performing work owns the interface it consumes. Simulation owns `PWorldBuilder`; a future Render Runtime owns its render-snapshot contract.
- Do not make every current type public. Design the smallest coherent extension surface needed by external content while keeping engine storage and backend internals encapsulated.
- The current fixed component-store list in `World` and fixed capability translation in `World.add(_:from:)` are the largest limitations on external consumer-defined components. Preserve strong typing and avoid solving this with a closed component enum or process-global registry.

Current example ownership:
- `Ball`, `BasicWorldBuilder`, and `BasicGameContent` are example Game Content.
- `Ball.usda` and `Ball.usdz` are example Game Content render assets, not reusable Render Runtime implementation.
- `ModelShaders.metal` is Render Runtime backend implementation unless a future explicit shader/material extension point makes part of it consumer content.
- Debug panes and app commands are example App tooling.
## Code Quality
Swift is a strongly typed language. In most cases, you should strongy type any piece of data being passed. if a type is being stored as an `Int` or `String` consider whether a bespoke type makes more sense. If adding or concatenating the data doesn't make sense, then we should consider that `Int` or `String` is going to allow that.
If there is a known list of possibilities for a type, consider `enum`.
## MCP Tooling Preferences
- Prefer the project-aware Xcode tooling available in the current session for builds, tests, file reads, and other IDE-side actions.
- Prefer the Apple documentation tooling available in the current session for framework and API lookups before falling back to general web search.
## Current Structure
- `Engine2/Engine2/Simulation Runtime/Engine/ECS/World.swift`
  - Central world object.
  - Owns component stores.
  - `add(_:from:)` translates advertised entity capabilities into component rows and validates that seed values match those capabilities.
  - `reserveEntityID()` currently allocates monotonically increasing indices with generation `0`; generation reuse/destruction is still future work.
- `Engine2/Engine2/Simulation Runtime/Engine/ECS/Entity.swift`
  - Base `Entity` superclass.
  - Holds `id` and `world`.
  - `InitialState` carries common spawn-time transform and motion seed values.
  - `init(unregisteredID:in:)` is for tests and future reconstruction paths.
  - `init(in:from:)` reserves an ID and registers the entity with `World`.
- `Engine2/Engine2/Simulation Runtime/Engine/ECS/EntityID.swift`
  - Entity handle with `index` and `generation`.
  - `generation` should remain meaningful; do not silently regress to index-only identity semantics.
- `Engine2/Engine2/Simulation Runtime/Engine/ECS/ComponentStore.swift`
  - Sparse-set style storage:
    - `dense`: component values
    - `entities`: entity IDs aligned with `dense`
    - `sparse`: entity index -> dense index
  - Lookup re-checks the full `EntityID`, including generation.
  - Use `update(for:_:)` for existing component mutations so systems update the dense row in place instead of rebuilding and reinserting replacement rows.
  - Removal, compaction, richer mutation helpers, and join/query helpers are still missing.
- `Engine2/Engine2/Simulation Runtime/Engine/Protocol/PComponent.swift`
  - Marker protocol for components.
  - Explicitly `nonisolated` so component `Codable` and `Equatable` value semantics do not inherit the app target's default `MainActor` isolation.
- `Engine2/Engine2/Simulation Runtime/Engine/Protocol/PResource.swift`
  - Marker protocol for long-lived resource and resource-like storage roles inside an owning runtime or world.
  - Sharing mechanism is not what defines a resource; ownership, lifetime, and non-entity cardinality are the important traits.
- `Engine2/Engine2/Simulation Runtime/Engine/Protocol/PSystem.swift`
  - Core system protocol used by the engine's ordered execution lists.
- `Engine2/Engine2/Simulation Runtime/Engine/Protocol/PWorldBuilder.swift`
  - Simulation-owned construction interface for producing fully bootstrapped worlds.
- `Engine2/Engine2/Simulation Runtime/Engine/Infrastructure/Clock/*.swift`
  - `PClock`, `ManualClock`, and `SystemClock` keep elapsed-time sampling in engine infrastructure and outside system logic.
- `Engine2/Engine2/Simulation Runtime/Engine/System/Position/Protocol/*.swift`
  - `PPositionable` exposes a live `position` backed by `World.positionComponents`.
  - `PMovable` exposes live motion state backed by `World.motionComponents`.
  - `POrientable` exposes live `rotation`.
  - `PRotatable` exposes live angular velocity and angular accumulator input.
  - `PScalable` exposes live `scale`.
- `Engine2/Engine2/Simulation Runtime/Engine/System/Selection/PSelectable.swift`
  - Convenience protocol for entity objects that expose live selection state.
- `Engine2/Engine2/Simulation Runtime/Engine/System/Position/Component/*.swift`
  - `CPosition`
  - `CMotion`
  - `CRotation`
  - `CAngularVelocity`
  - `CAngularMotionAccumulator`
  - `CScale`
  - `CAcceleration` no longer exists; keep the aggregate accumulator direction.
- `Engine2/Engine2/Simulation Runtime/Engine/System/Selection/CSelectable.swift`
  - Selection-state component used by `PSelectable` entities and selection UI.
- `Engine2/Engine2/Simulation Runtime/Engine/System/Input/**/*.swift`
  - `InputState` is the current authoritative simulation-facing input resource stored on `World`.
  - The proposed Input Runtime will eventually separate platform input collection from immutable input snapshots consumed by the Simulation Runtime.
  - `SInputMapping` translates raw input into higher-level camera actions.
  - `SInputHistory` records compact input history rows for debug UI.
  - `SInputCleanup` clears per-tick transient input after always-running input systems have consumed it.
- `Engine2/Engine2/Simulation Runtime/Engine/System/Position/System/*.swift`
  - `SAccelerationIntent` emits persistent acceleration intent into `CMotion`'s per-tick accumulator.
  - `SMovement` integrates `CMotion` accumulator input into velocity, moves position, then clears the accumulator.
  - `SRotation` integrates angular accumulator input into angular velocity, advances rotation, normalizes it, then clears the accumulator.
- `Engine2/Engine2/Simulation Runtime/Engine/System/SCameraInput.swift`
  - Applies mapped camera orbit and zoom input to `World.camera`.
- `Engine2/Engine2/Simulation Runtime/Engine/*.swift`
  - `Engine` owns fixed-step accumulation and ordered system execution.
  - `Engine` currently maintains separate always-running and simulation-gated system lists.
- `Engine2/Engine2/Simulation Runtime/SimulationRuntime.swift`
  - `SimulationRuntime` owns session bootstrap and app-facing lifecycle policy above `Engine`.
- `Engine2/Engine2/Simulation Runtime/SimulationLoop.swift`
  - `SimulationLoop` owns the app-level async polling task and feeds elapsed time into `Engine`.
- `Engine2/Engine2/Game Content/BasicWorldBuilder.swift`
  - Example Game Content builder that currently seeds the default `Ball` entities.
- `Engine2/Engine2/Game Content/Entity/Ball.swift`
  - Example entity object/facade.
  - Advertises `MeshID.ball` through `PRenderable`; it does not know the model filename or renderer backend.
  - Represents the intended style of game object API more than a finished implementation.
- `Engine2/Engine2/Simulation Runtime/Engine/System/Rendering/**/*.swift`
  - `CRenderable` stores only an abstract `MeshID` in ECS state.
  - `PRenderable` seeds that component from Game Content entities and exposes its live value.
- `Engine2/Engine2/Render Runtime/*.swift`
  - `RenderFrame.extract(from:)` is the current simulation-to-render snapshot boundary and includes only entities with explicit `CRenderable` presentation state.
  - `RenderAssetCatalog` is the render-owned input contract mapping `MeshID` values to packaged model references.
  - `MetalSceneView` bridges SwiftUI to MetalKit input and drawing.
  - `MetalRenderer` consumes `RenderFrame` using backend-specific state retained by its `MetalResourceStore`.
- `Engine2/Engine2/Render Runtime/Resource/*.swift`
  - `MetalResourceStore` is the device-scoped owner of the Metal 4 compiler, command queue, typed shader/pipeline/depth/argument-table caches, decoded models, and frame resources.
  - `MetalResidencyManager` keeps static asset allocations and per-frame allocations in separate committed residency sets and registers externally owned view/layer sets with the command queue.
  - Residency is not object ownership: the store retains backend objects, while residency sets group only `MTLAllocation` values needed by submitted GPU work.
- `Engine2/Engine2/UI/Input/InputMetalView.swift`
  - Platform input collection currently lives in the experimental SwiftUI-facing UI layer.
- `Engine2/Engine2Tests/`
  - Swift Testing coverage exists for the engine loop, clocks, world builder, spawn seeding, movement, rotation, rotation codability/equality, and several capability protocol read paths.
  - The test tree mirrors the app/source tree where practical.
### Folder Organization
New simulation systems are added to `Engine2/Engine2/Simulation Runtime/Engine/System/<system name>.`
When a new system is created, the requisite components, resources, and protocols will be added in their own subfolders. The `System` folders are organized in funcitonal blocks to ensure proximity of files used in that `System`.
## High-Level Direction
### 1. Keep Protocols
Protocols are staying.
They serve two purposes:
- ergonomic game-level typing (`Ball: PMovable`, `Ball: PSelectable`, etc.)
- a clean bridge to UI and tooling, where code wants typed objects rather than raw component rows
Do not remove the protocol layer unless the project direction changes deliberately.
### 2. Use `Entity` as a Base Class for Live Objects
The project is trending toward `Entity` as a superclass rather than a protocol.
Intent:
- common identity/lifecycle plumbing lives in one place
- concrete game objects are reference types with stable identity
- capability protocols sit on top of that base class
Important:
- systems should not use these objects in hot loops
- these objects are facades/bridges, not the simulation backend
### 3. ECS Is the Simulation Truth
The world's component stores are authoritative.
Entity classes should read from component stores through protocol default implementations. They are not meant to duplicate gameplay state as a second authoritative model.
If future UI code needs current data, prefer:
- live computed accessors backed by component stores
- typed lookup from `EntityID`
- optional object registry or on-demand typed handle reconstruction
### 4. Systems Iterate Stores Directly
This is a key design decision from the conversation:
- systems should iterate `ComponentStore`s directly
- systems should mutate existing component rows with `ComponentStore.update(for:_:)` when changing component fields; reserve `insert` for spawn/registration, adding a missing row, or intentional row replacement/reset
- systems should not read/write motion through entity property wrappers inside hot loops
- object facades are for gameplay ergonomics, scripting-ish code, UI, and selection/inspection flows
If a future system needs `position + velocity`, it should join component stores directly, not loop over `Entity` objects.
### 5. Prefer Simple OOP Creation at the Boundary
Do not over-engineer descriptors/snapshots unless they become necessary.
The favored direction is simple object-oriented creation like:
```swift
let ball = Ball(...)
```
or a closely related `spawn`/factory variant.
The important idea is:
- gameplay code should remain ergonomic
- ECS conversion happens at the world boundary
If spawn-time data needs to be carried through protocols, prefer small, practical values such as `initialPosition`, `initialVelocity`, etc. Avoid introducing multiple nearly identical "spawn/descriptor/snapshot" types unless there is a concrete need.
Current note: `Entity.InitialState` is a practical common seed bag for transform and motion data. Do not let it grow into a dumping ground for specialized gameplay state; prefer concrete entity initializers, world builders, or focused future spawn helpers for data that is not broadly engine-level.
### 6. Motion Model: Use Contribution Accumulation
The project has moved toward a motion contribution model.
Use `CMotion` for translational motion state:
- `velocity`: integrated world-space velocity
- `accelerationIntent`: persistent drive state such as idle or accelerating
- `accumulator.acceleration`: per-tick continuous influences that scale with `dt`
- `accumulator.impulse`: per-tick instantaneous velocity changes that do not scale with `dt`
Design intent:
- gameplay systems emit motion contributions
- persistent drive state is converted into accumulator input before movement
- movement updates velocity, then updates position
Avoid having many systems directly overwrite `CMotion.velocity` unless they are doing explicit override/constraint/collision resolution work.
The runtime-first version of this model is aggregate accumulation, not a per-entity heap of arbitrary contribution objects. If source-level contribution tracking is ever needed for debugging, add that separately.
The angular equivalent is `CAngularMotionAccumulator`:
- `angularAcceleration`: continuous rotational influences that scale with `dt`
- `angularImpulse`: instantaneous angular velocity changes
`SMovement` and `SRotation` currently combine contribution integration and transform advancement. If collision, constraints, or staged scheduling become substantial, consider splitting those phases while preserving the same accumulator semantics.
### Component Updates Should Be In-Place
When a component row already exists, prefer `ComponentStore.update(for:_:)` over constructing a replacement component and passing it back through `insert`.
Use `insert` for:
- spawn-time component creation
- adding a row that may not exist yet
- explicit reset/reseed operations where replacing the full component is the intended behavior
Use `update(for:_:)` for:
- per-tick system mutation
- changing one or two fields on an existing component
- clearing accumulators after integration
- updating transform, motion, or other dense-row state in hot paths
This keeps systems data-oriented and avoids extra sparse lookups, generation checks, and whole-value reconstruction when the dense row can be safely mutated in place.
## Deep-Dive Notes From Current Code
### Spawn Flow Is Capability-Driven
`World.add(_:from:)` is now the boundary where entity protocol conformances turn into component rows. Keep capability defaults centralized there so concrete entities stay ergonomic and do not duplicate ECS row construction.
Calling `add` again for the same live entity currently replaces rows. Treat it as spawn-time registration unless a future explicit reset/reseed operation is introduced.
### Generation Safety Is Partially Implemented
`ComponentStore` lookups use `entity.index` for the sparse lookup but then confirm the full `EntityID`, including generation. That protects reads from stale generations.
However, the store does not yet remove or compact dense rows. If a future free list reuses indices with incremented generations, old dense rows can remain in `entities` and still be visited by direct iteration. Before enabling index reuse, implement component removal/compaction and add tests for stale-generation iteration behavior.
### Facades Are Live Handles
Entity objects hold an `unowned` world reference and computed protocol accessors fatal-error when required backing rows are missing. That is acceptable for strict live game objects, but UI inspection or editor tooling may eventually need optional, non-crashing lookup APIs.
### Engine Loop Boundaries Are Clear
`Engine` owns fixed-step accumulation and ordered system execution. `SimulationRuntime` owns app-facing lifecycle and session policy, while `SimulationLoop` polls wall time on the main actor. Keep those responsibilities above `Engine` so the core engine remains easy to test.
The fixed-step loop does not yet have overload protection. If large deltas become possible, prefer explicit max-step/backlog policy over silently running unbounded catch-up work.
### Rendering Docs Are Directional
The DocC runtime and render articles contain proposed architecture, not only implemented code. Their important constraints are:
- keep backend-specific Metal state out of `World`
- store only abstract presentation state or handles in ECS
- publish an immutable render snapshot without requiring a Render Runtime to exist
- let the Render Runtime consume completed snapshots according to its own cadence
### Documentation Can Drift Quickly
The code has already moved past earlier examples such as `Missile` and `CAcceleration`. When editing docs or contributor guidance, check current source names first and update examples to match durable concepts rather than stale placeholder types.
## Guidance for Future Changes
- Do not reintroduce a global static world lookup model.
- Do not introduce process-global mutable resources or runtime service locators to connect runtimes.
- Keep runtime dependencies explicit and wire them at the App boundary.
- Prefer immutable snapshots and events over direct peer-runtime references.
- Do not reintroduce a closed enum registry for component identity.
- Keep component storage per-type.
- Keep systems data-oriented.
- In systems and other mutation-heavy paths, use `ComponentStore.update(for:_:)` for existing rows instead of `insert`-as-replace.
- Keep `World.add(_:from:)` as a capability-to-component boundary unless a clearly better spawn API replaces it.
- Add explicit contribution APIs when needed instead of making many systems or object facades directly overwrite integrated velocity.
- Comment executable logic generously. If a method does real work, prefer a short doc comment plus inline comments at the important steps so control flow and state changes are obvious when reading the code.
- When the user asks for ideas, architecture notes, or future direction to be captured for later, prefer adding or updating DocC content under `Engine2/Engine2.docc/` rather than leaving that intent only in chat or code comments.
- For not-yet-implemented direction, mark the DocC content clearly as proposed or future work, and link new conceptual articles from the DocC landing page when they represent durable engine design.
- Preserve or improve `EntityID.generation` semantics.
- Do not reuse an entity index until component removal and dense iteration behavior are generation-safe.
- Prefer adding capability protocols over deepening inheritance.
- Keep the game-object layer ergonomic, but keep the ECS layer authoritative.
- If adding selection/UI inspection, typed lookup by `EntityID` is a valid direction.
- Mirror the app/source tree under `Engine2/Engine2Tests/`. For example, tests for `Engine2/Engine2/Simulation Runtime/Engine/System/Position/System/SMovement.swift` should live in `Engine2/Engine2Tests/Simulation Runtime/Engine/System/Position/System/SMovementTests.swift`.
## Current Gaps / Known TODOs
- Entity destruction, index reuse, and generation incrementing are not implemented.
- `ComponentStore` still needs removal, dense compaction, richer mutation/query helpers, and explicit tests for stale-generation behavior.
- Systems still run in one ordered list; the DocC scheduling graph/stage model is proposed, not implemented.
- `SMovement` and `SRotation` currently combine integration and transform advancement; the future collision/constraint pipeline may need a more explicit phase split.
- Rendering extraction, render resources, and presentation buffers are only documented direction.
- Capability accessors are strict live reads with `fatalError`; optional inspection/editor lookup paths do not exist yet.
- Tests do not yet cover component removal, dense iteration with stale generations, spawn precondition failures, or fixed-step overload policy.
## Working Assumption for Contributors
When in doubt, choose the simpler design that preserves:
- typed game objects at the API boundary
- component stores as runtime truth
- systems as the place where simulation work happens
That is the core intent this repo is trying to protect.
