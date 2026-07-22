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
- `InputRuntime` owns platform input state and publishes its latest immutable `InputSnapshot` through `PInputSnapshotSource`; platform adapters submit `InputEvent` values through `PInputEventSink`.
- `SimulationRuntime` owns one authoritative session, `Engine`, and `World`; it accepts exact cursor-qualified advance requests and does not own wall-clock cadence or a live Input source.
- `RealtimeAdvanceDriver` is an App-owned connection object that samples wall time and the configured latest Input publication, then submits immutable assignments through `PSimulationAdvanceTarget`.
- `RealtimeConfiguration` composes Input, Simulation, the real-time driver, and one App-owned `ScreenViewpointController`. `ManualConfiguration` composes caller-driven Simulation without Input or an automatic cadence.
- `SimulationLoop` and `Engine.update(deltaTime:inputSnapshot:)` remain only as an unused legacy path while their focused tests and partial-schedule behavior are retired.
- `InputMetalView` submits host `InputEvent` values to `RealtimeAssembly`. That assembly currently performs a deliberate hard-coded fan-out to `InputRuntime` and its screen viewpoint controller; it does not call the Simulation Runtime or mutate `World`.
- `ScreenViewpointController` is an ordinary App-owned presentation controller, not a Runtime. It can revise one screen's free-orbit viewpoint while Simulation is paused.
- `SimulationPresentationSnapshot` is the Simulation Runtime-owned latest completed presentation value. Its camera is the publisher-authored default when an output supplies no override.
- `RenderViewpoint` is an immutable output-specific camera value with stable identity and monotonic revision. `RenderFrame` is the Render Runtime-owned private projection that preserves the source Simulation cursor plus optional explicit-viewpoint identity and revision.
- `MetalSceneView` and `MetalRenderer` cover early Render Runtime responsibilities. The renderer samples Simulation presentation and viewpoint sources independently at draw cadence and never reads live `World` state.

The current screen fan-out is intentionally one concrete connection, not a generalized routing framework. Multi-source input, typed routes and route epochs, multi-window/output bindings, Simulation observer anchors, offscreen rendering, and MCP composition remain proposed.

Do not rename or wrap existing types solely to match the vocabulary. Introduce a runtime boundary when it creates concrete ownership, lifecycle, cadence, or testing value.

## Game Content Architecture
The proposed consumer-content boundary is documented in `Engine2/Engine2.docc/Articles/Game-Content-Architecture.md`.

Use these terms and constraints consistently:
- **Game Content** is consumer-defined game code, descriptions, catalogs, and assets used to construct and configure runtimes. It is not a runtime and has no independent cadence or lifecycle.
- The App is the composition root. It constructs Game Content, then supplies the relevant portions to independently constructed runtimes.
- Use **Asset** for packaged source content such as models, textures, sounds, animations, and levels. Do not conflate assets with ECS or runtime resources, even though SwiftPM calls bundled files resources.
- Game Content owns the exhaustive, strongly typed, backend-neutral identities for the entities and assets it defines, such as the current `MeshID` and `MaterialID` and a future `SoundID` enum. Runtimes may carry and resolve those values, but they do not own the content vocabulary. Do not store raw `MTLBuffer`, `MTKMesh`, decoded audio, or other backend objects in ECS or Game Content.
- Runtimes privately resolve content assets into backend resources. Game Content does not own runtime caches, GPU allocations, decoded audio, or runtime lifecycle.
- Continuous presentation can be described through abstract ECS state and snapshots. Ephemeral presentation should normally derive from Simulation Runtime events plus consumer-supplied presentation rules.
- Consumer Game Content may eventually define entities, components, optional behaviors, world builders, render/audio descriptions, asset catalogs, and event-presentation mappings through deliberate public Engine2 APIs.
- The Simulation Runtime owns invariant systems and their foundational schedule. Future Game Content behavior must enter through controlled extension points rather than replacing that foundation.
- The runtime performing work owns the interface it consumes. Simulation owns `PWorldBuilder`; Render owns `RenderFrame` and its projection from the publisher-owned `SimulationPresentationSnapshot` contract.
- Do not make every current type public. Design the smallest coherent extension surface needed by external content while keeping engine storage and backend internals encapsulated.
- The current fixed component-store list in `World` and fixed capability translation in `World.add(_:from:)` are the largest limitations on external consumer-defined components. Preserve strong typing and avoid solving this with a closed component enum or process-global registry.

Current example ownership:
- `Ball`, `BasicWorldBuilder`, and `BasicGameContent` are example Game Content.
- `Ball.usda` and `Ball.usdz` are example Game Content render assets, not reusable Render Runtime implementation.
- `ModelShaders.metal` is Render Runtime backend implementation unless a future explicit shader/material extension point makes part of it consumer content.
- Debug panes and app commands are example App tooling.
## Code Quality
- Never add Xcode-style file header comments that repeat a filename or project name or record who created a file, when it was created, or a boilerplate copyright notice. Remove these headers whenever you encounter them.
- Give production types meaningful `///` documentation comments that make Xcode Quick Help useful. Explain the type's role, ownership, important invariants, and intended boundary rather than merely restating its name.
- One type per file is a project rule. Name the file after the type; extensions of that type may remain with it when doing so preserves cohesion.
- Swift is strongly typed. Prefer a domain type whenever an `Int` or `String` would permit meaningless arithmetic, concatenation, or invalid values.
- If a value has a known, finite list of possibilities, use an `enum`.
- Using `String` or a string-backed wrapper in place of an enum for a closed set is heavily discouraged. Any exception must be justified with a code or documentation comment explaining why the vocabulary is genuinely open-ended or why an external API requires strings.
## MCP Tooling Preferences
- Prefer the project-aware Xcode tooling available in the current session for builds, tests, file reads, and other IDE-side actions.
- Prefer the Apple documentation tooling available in the current session for framework and API lookups before falling back to general web search.
## Current Structure
- `Engine2/Simulation Runtime/Engine/ECS/World.swift`
  - Central world object.
  - Owns component stores.
  - `add(_:from:)` translates advertised entity capabilities into component rows and validates that seed values match those capabilities.
  - `reserveEntityID()` currently allocates monotonically increasing indices with generation `0`; generation reuse/destruction is still future work.
- `Engine2/Simulation Runtime/Engine/ECS/Entity.swift`
  - Base `Entity` superclass.
  - Holds `id` and `world`.
  - `InitialState` carries common spawn-time transform and motion seed values.
  - `init(unregisteredID:in:)` is for tests and future reconstruction paths.
  - `init(in:from:)` reserves an ID and registers the entity with `World`.
- `Engine2/Simulation Runtime/Engine/ECS/EntityID.swift`
  - Entity handle with `index` and `generation`.
  - `generation` should remain meaningful; do not silently regress to index-only identity semantics.
- `Engine2/Simulation Runtime/Engine/ECS/ComponentStore.swift`
  - Sparse-set style storage:
    - `dense`: component values
    - `entities`: entity IDs aligned with `dense`
    - `sparse`: entity index -> dense index
  - Lookup re-checks the full `EntityID`, including generation.
  - Use `update(for:_:)` for existing component mutations so systems update the dense row in place instead of rebuilding and reinserting replacement rows.
  - Removal, compaction, richer mutation helpers, and join/query helpers are still missing.
- `Engine2/Simulation Runtime/Engine/Protocol/PComponent.swift`
  - Marker protocol for components.
  - Explicitly `nonisolated` so component `Codable` and `Equatable` value semantics do not inherit the app target's default `MainActor` isolation.
- `Engine2/Simulation Runtime/Engine/Protocol/PResource.swift`
  - Marker protocol for long-lived resource and resource-like storage roles inside an owning runtime or world.
  - Sharing mechanism is not what defines a resource; ownership, lifetime, and non-entity cardinality are the important traits.
- `Engine2/Simulation Runtime/Engine/Protocol/PSystem.swift`
  - Core system protocol used by the engine's ordered execution lists.
- `Engine2/Simulation Runtime/Engine/Protocol/PWorldBuilder.swift`
  - Simulation-owned construction interface for producing fully bootstrapped worlds.
- `Engine2/Simulation Runtime/Engine/Infrastructure/Clock/SystemClock.swift`
  - `SystemClock` provides injectable monotonic elapsed-time sampling to `RealtimeAdvanceDriver` and the legacy `SimulationLoop`, outside exact Simulation execution and system logic.
- `Engine2/Simulation Runtime/Engine/System/Position/Protocol/*.swift`
  - `PPositionable` exposes a live `position` backed by `World.positionComponents`.
  - `PMovable` exposes live motion state backed by `World.motionComponents`.
  - `POrientable` exposes live `rotation`.
  - `PRotatable` exposes live angular velocity and angular accumulator input.
  - `PScalable` exposes live `scale`.
- `Engine2/Simulation Runtime/Engine/System/Selection/PSelectable.swift`
  - Convenience protocol for entity objects that expose live selection state.
- `Engine2/Simulation Runtime/Engine/System/Position/Component/*.swift`
  - `CPosition`
  - `CMotion`
  - `CRotation`
  - `CAngularVelocity`
  - `CAngularMotionAccumulator`
  - `CScale`
  - `CAcceleration` no longer exists; keep the aggregate accumulator direction.
- `Engine2/Simulation Runtime/Engine/System/Selection/CSelectable.swift`
  - Selection-state component used by `PSelectable` entities and selection UI.
- `Engine2/Simulation Runtime/Engine/System/Input/**/*.swift`
  - `InputState` is the authoritative simulation-facing input resource stored on `World`, populated from `InputSnapshot` only at fixed-step boundaries.
  - `SInputMapping` is a legacy camera-action mapper retained with focused tests pending deletion; it is no longer part of `Engine`'s default schedule.
  - `SInputHistory` records compact input history rows for debug UI.
  - `SInputCleanup` clears per-tick transient input after always-running input systems have consumed it.
- `Engine2/Simulation Runtime/Engine/System/Position/System/*.swift`
  - `SAccelerationIntent` emits persistent acceleration intent into `CMotion`'s per-tick accumulator.
  - `SMovement` integrates `CMotion` accumulator input into velocity, moves position, then clears the accumulator.
  - `SRotation` integrates angular accumulator input into angular velocity, advances rotation, normalizes it, then clears the accumulator.
- `Engine2/Simulation Runtime/Engine/System/SCameraInput.swift`
  - Legacy Simulation-owned free-orbit implementation retained with focused tests pending deletion; it is no longer part of `Engine`'s default schedule.
- `Engine2/Simulation Runtime/Engine/*.swift`
  - `Engine` owns exact fixed-step execution and ordered system orchestration; its elapsed-time accumulator remains only on the unused legacy update path.
  - `Engine` currently maintains separate always-running and simulation-gated system lists. Its default always-running list now contains history and cleanup only; output viewpoint control is outside Simulation.
- `Engine2/Simulation Runtime/SimulationRuntime.swift`
  - `SimulationRuntime` owns session bootstrap, exact serialized advancement, explicit input-baseline application, and completed presentation publication above `Engine`.
- `Engine2/Simulation Runtime/SimulationLoop.swift`
  - `SimulationLoop` is the unused legacy elapsed-time adapter retained temporarily with its focused tests; new App composition must use `RealtimeAdvanceDriver` and the Runtime-level exact capability.
- `Engine2/Runtime Configuration/Realtime/*.swift`
  - `RealtimeConfiguration` constructs independently owned Input and Simulation Runtimes, one `RealtimeAdvanceDriver`, and one `ScreenViewpointController`.
  - `RealtimeAssembly` owns lifecycle ordering, pause policy, async drain-before-stop/rebuild, lifecycle-generation protection for coordinated Simulation cutovers, and the current hard-coded screen-event fan-out.
  - `RealtimeAdvanceDriver` alone translates elapsed wall time into bounded exact cursor-qualified requests, applies configured overflow treatment, captures transition input baselines plus one later immutable publication per batch, faults on an unexpected authority mismatch, and does not retain an otherwise abandoned assembly between sleeps.
- `Engine2/Runtime Configuration/Realtime/Viewpoint/*.swift`
  - `ScreenViewpointController` owns an optional free-orbit override for one screen. Before the first meaningful gesture, and after reset, it passes through the exact latest Simulation-published default camera.
- `Engine2/Runtime Configuration/Manual/*.swift`
  - `ManualConfiguration` and `ManualAssembly` expose caller-driven exact advancement without Input or a polling task.
- `Engine2/Input Runtime/**/*.swift`
  - `InputRuntime` is the App-owned lifecycle boundary for platform input collection.
  - `PInputEventSink` is the platform-adapter ingress accepted by the runtime.
  - `PInputSnapshotSource` exposes the latest immutable `InputSnapshot` without exposing runtime mutation.
  - `InputRevision` identifies publication sessions and versions. Within one session, cumulative pointer-motion and scroll totals let a slower consumer derive all motion between sampled snapshots without requiring one-to-one cadence.
  - The current `InputEvent` is host ingress, not a published ordered runtime event lane. Ordered discrete transitions and retained replay remain future work.
- `Engine2/Game Content/BasicWorldBuilder.swift`
  - Example Game Content builder that seeds a deterministic six-Ball PBR material grid. Every Ball is quiescent, shares `MeshID.ball`, and selects one smooth, baseline, or rough warm-dielectric or gold-metal `MaterialID`.
- `Engine2/Game Content/Model/MeshID.swift`
  - Game Content-owned enum defining the complete mesh identity vocabulary consumed by simulation presentation state and render catalog lookup.
- `Engine2/Game Content/Material/MaterialID.swift`
  - Game Content-owned enum defining the complete authored material identity vocabulary carried by simulation and resolved privately by Render.
- `Engine2/Game Content/Entity/Ball.swift`
  - Example entity object/facade.
  - Advertises `MeshID.ball` and its per-instance `MaterialID` through `PRenderable`; it does not know the model filename, material factors, or renderer backend.
  - Represents the intended style of game object API more than a finished implementation.
- `Engine2/Simulation Runtime/Engine/System/Rendering/**/*.swift`
  - `CRenderable` stores only abstract `MeshID` and `MaterialID` values in ECS state.
  - `PRenderable` seeds those identities from Game Content entities and exposes their live values.
- `Engine2/Simulation Runtime/Snapshot/*.swift`
  - `SimulationTick` identifies completed fixed steps without wall-clock or render-cadence meaning.
  - `SimulationPresentationSnapshot` publishes immutable camera and entity presentation state through `SimulationRuntime.latestPresentationSnapshot`.
  - `PSimulationPresentationSource` exposes that latest-value publication as a read-only capability without exposing the wider Simulation Runtime API.
  - Ordinary live publication uses latest-value semantics; retained replay history remains an explicit future recorder concern.
- `Engine2/Render Runtime/Asset/*.swift`
  - `RenderAssetCatalog` is the render-owned input contract mapping `MeshID` values to packaged model references and `MaterialID` values to authored `PBRMaterialDescription` values.
- `Engine2/Render Runtime/Frame/*.swift`
  - `RenderFrame.project(from:viewpoint:)` converts a `SimulationPresentationSnapshot` into private render instances, uses an explicit viewpoint when supplied, otherwise falls back to the snapshot camera, and preserves optional source-cursor and viewpoint attribution.
- `Engine2/Render Runtime/Viewpoint/*.swift`
  - `RenderViewpoint` carries one output-specific camera, stable `RenderViewpointID`, and monotonic `RenderViewpointRevision` through the Render-owned `PRenderViewpointSource` boundary.
- `Engine2/Render Runtime/Metal/**/*.swift`
  - `MetalRenderer` resolves an optional output viewpoint independently from the latest Simulation presentation, projects both into `RenderFrame`, and consumes that frame using backend-specific state retained by its `MetalResourceStore`.
  - Per-frame state, render passes, backend resources, and Swift/Metal shader contracts live in focused subfolders beneath the Metal backend.
- `Engine2/Render Runtime/Metal/Resource/*.swift`
  - `MetalResourceStore` is the device-scoped owner of the Metal 4 compiler, command queue, typed shader/pipeline/depth/argument-table caches, validated authored material descriptions, decoded models, and frame resources.
  - `MetalResidencyManager` keeps static asset allocations and per-frame allocations in separate committed residency sets and registers externally owned view/layer sets with the command queue.
  - Residency is not object ownership: the store retains backend objects, while residency sets group only `MTLAllocation` values needed by submitted GPU work.
- `Engine2/Render Runtime/View/*.swift`
  - `MetalSceneView` bridges SwiftUI to MetalKit input and drawing and wires separate presentation, viewpoint, and input-sink capabilities selected by the App.
- `Engine2/UI/ContentView.swift`
  - Root App UI that composes independently owned runtime capabilities and app-level controls.
- `Engine2/UI/Input/InputMetalView.swift`
  - Platform adapter that translates AppKit events into `InputEvent` values and submits them through `PInputEventSink`.
- `Engine2UnitTests/`
  - Fast, deterministic Swift Testing coverage directly exercises individual production types and methods.
  - The unit-test tree mirrors the app/source tree where practical.
  - Render contract, frame, presentation, and CPU-side shader-layout tests mirror their production folders under `Engine2UnitTests/Render Runtime/`.
- `Engine2RenderTests/`
  - Render integration coverage owns shader execution, offscreen GPU submission, renderer/resource assembly, packaged model decoding, and end-to-end presentation validation.
  - Test-only Metal renderers and GPU submission helpers remain private to this target instead of compiling into the unit-test bundle.
  - Render integration tests mirror the Metal backend folders, with shared test-only infrastructure grouped under `Engine2RenderTests/Render Runtime/Metal/Support/`.
### Folder Organization
New simulation systems are added to `Engine2/Simulation Runtime/Engine/System/<system name>.`
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
`Engine` owns deterministic fixed-step execution and ordered systems. `SimulationRuntime` owns the authoritative session and exact request boundary. `RealtimeAdvanceDriver` owns wall-clock sampling, remainder, input capture, and pause policy, while `RealtimeAssembly` owns coordinated lifecycle and rebuild cutovers. Keep cadence and peer wiring outside Simulation so the exact core remains easy to test and reuse.
The real-time driver uses a typed per-wake catch-up cap with explicit preserve/discard overflow treatment. The legacy `Engine.update(deltaTime:inputSnapshot:)` path remains unbounded until removal; do not use it as the basis for new real-time policy.
### Viewpoint Control Is Presentation-Owned
`World.camera` and the camera in `SimulationPresentationSnapshot` provide Simulation's completed default. `ScreenViewpointController` owns the current screen override, and Render resolves that separate value when it projects a frame. Do not put output-specific orbit or zoom back into the default Simulation schedule merely to redraw while paused.

The current `RealtimeAssembly.receive(_:)` fan-out proves one-screen separation only. Do not mistake it for multi-source input routing, route epochs, recipient baselines, observer anchors, or multi-output binding infrastructure.
### Rendering Docs Are Directional
The DocC runtime and render articles contain proposed architecture, not only implemented code. Their important constraints are:
- keep backend-specific Metal state out of `World`
- store only abstract presentation state or handles in ECS
- publish an immutable render snapshot without requiring a Render Runtime to exist
- let the Render Runtime consume completed snapshots according to its own cadence
- let each output resolve an explicit viewpoint independently, with the Simulation-published camera as a valid fallback
### Documentation Can Drift Quickly
The code has already moved past earlier examples such as `Missile` and `CAcceleration`. When editing docs or contributor guidance, check current source names first and update examples to match durable concepts rather than stale placeholder types.
## Guidance for Future Changes
- Do not reintroduce a global static world lookup model.
- Do not introduce process-global mutable resources or runtime service locators to connect runtimes.
- Keep runtime dependencies explicit and wire them at the App boundary.
- Keep output-specific viewpoint state outside authoritative Simulation state; feed it back only through a deliberate Simulation-owned command when gameplay truly requires it.
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
- Mirror direct type and method tests under `Engine2UnitTests/`. For example, tests for `Engine2/Simulation Runtime/Engine/System/Position/System/SMovement.swift` should live in `Engine2UnitTests/Simulation Runtime/Engine/System/Position/System/SMovementTests.swift`.
- Place tests that validate Render across multiple production boundaries under `Engine2RenderTests/`. This includes real shader execution, command submission, GPU lifetime, renderer assembly, and packaged-model decoding.
## Current Gaps / Known TODOs
- Entity destruction, index reuse, and generation incrementing are not implemented.
- `ComponentStore` still needs removal, dense compaction, richer mutation/query helpers, and explicit tests for stale-generation behavior.
- Systems still run in two ordered lists; the DocC scheduling graph/stage model is proposed, not implemented.
- `SMovement` and `SRotation` currently combine integration and transform advancement; the future collision/constraint pipeline may need a more explicit phase split.
- Typed multi-source input routing, route epochs, multi-window/output bindings, Simulation observer anchors, production offscreen rendering, and MCP composition remain proposed.
- Capability accessors are strict live reads with `fatalError`; optional inspection/editor lookup paths do not exist yet.
- Tests do not yet cover component removal, dense iteration with stale generations, or spawn precondition failures.
- The legacy `SimulationLoop`, `Engine.update(deltaTime:inputSnapshot:)`, elapsed-time accumulator, and partial-schedule pause path still need focused-test migration and removal.
- Legacy `SInputMapping` and `SCameraInput` source and focused tests remain pending deletion even though the default `Engine` schedule no longer installs them.
## Working Assumption for Contributors
When in doubt, choose the simpler design that preserves:
- typed game objects at the API boundary
- component stores as runtime truth
- systems as the place where simulation work happens
That is the core intent this repo is trying to protect.
