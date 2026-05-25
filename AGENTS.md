# Engine2 AGENTS Guide

## Repo Summary

Engine2 is a compact Swift ECS experiment with a small but increasingly
coherent runtime shape. The project is moving toward a hybrid model:

- ECS component stores are the runtime source of truth.
- Entity objects are ergonomic, typed facades over ECS state.
- Capability protocols such as `Movable` and `Positionable` are kept as the
  game-facing/UI-facing surface.
- Systems should operate directly on component stores in hot paths.

This repo is still early, but several core paths now exist. Preserve direction
and intent when filling in missing pieces.

## MCP Tooling Preferences

- Prefer the `sosumi` MCP server for Apple and Xcode documentation lookups.
- Prefer the `xcode` MCP server for interacting with Xcode itself, including
  project-aware build, test, and IDE-side actions.
- When both are relevant, use `sosumi` for documentation/reference gathering
  and `xcode` for actions against the open Xcode project.

## Current Structure

- `Engine2/World/World.swift`
  - Central world object.
  - Owns component stores.
  - `add(_:from:)` translates advertised entity capabilities into component
    rows and validates that seed values match those capabilities.
  - `reserveEntityID()` currently allocates monotonically increasing indices
    with generation `0`; generation reuse/destruction is still future work.

- `Engine2/World/Entity.swift`
  - Base `Entity` superclass.
  - Holds `id` and `world`.
  - `InitialState` carries common spawn-time transform and motion seed values.
  - `init(unregisteredID:in:)` is for tests and future reconstruction paths.
  - `init(in:from:)` reserves an ID and registers the entity with `World`.

- `Engine2/World/EntityID.swift`
  - Entity handle with `index` and `generation`.
  - `generation` should remain meaningful; do not silently regress to
    index-only identity semantics.

- `Engine2/World/ComponentStore.swift`
  - Sparse-set style storage:
    - `dense`: component values
    - `entities`: entity IDs aligned with `dense`
    - `sparse`: entity index -> dense index
  - Lookup re-checks the full `EntityID`, including generation.
  - Removal, compaction, richer mutation helpers, and join/query helpers are
    still missing.

- `Engine2/Protocol/Component.swift`
  - Marker protocol for components.

- `Engine2/Protocol/Positionable.swift`
  - Convenience protocol for entity objects that can expose a live `position`
    backed by the world component store.

- `Engine2/Protocol/Movable.swift`
  - Convenience protocol for entity objects that can expose live `velocity`,
    `acceleration`, and `impulse` backed by world component stores.

- `Engine2/Protocol/Orientable.swift`
  - Convenience protocol for entity objects that expose live `rotation`.

- `Engine2/Protocol/Rotatable.swift`
  - Convenience protocol for entity objects that expose live angular velocity
    and angular motion contributions.

- `Engine2/Protocol/Scalable.swift`
  - Convenience protocol for entity objects that expose live `scale`.

- `Engine2/Component/*.swift`
  - `CPosition`
  - `CVelocity`
  - `CMotionAccumulator`
  - `CRotation`
  - `CAngularVelocity`
  - `CAngularMotionAccumulator`
  - `CScale`
  - `CAcceleration` no longer exists; keep the aggregate accumulator direction.

- `Engine2/System/*.swift`
  - `SMovement` integrates translational accumulator input into velocity, moves
    position, then clears the accumulator.
  - `SRotation` integrates angular accumulator input into angular velocity,
    advances rotation, normalizes it, then clears the accumulator.
  - These are real systems, but the broader scheduling/collision/presentation
    pipeline is still incomplete.

- `Engine2/Engine/*.swift`
  - `Engine` owns fixed-step accumulation and ordered system execution.
  - `Clock`, `ManualClock`, and `SystemClock` keep time sampling outside system
    logic.
  - `GameLoop` owns the app-level async polling task and feeds elapsed time into
    `Engine`.

- `Engine2/Game/*.swift`
  - `Game` owns session bootstrap policy above `Engine`.
  - `WorldBuilder` creates fully bootstrapped worlds.
  - `BasicWorldBuilder` currently seeds a default `Ball`.

- `Engine2/Entity/Ball.swift`
  - Example entity object/facade.
  - Represents the intended style of game object API more than a finished
    implementation.

- `Engine2Tests/`
  - Swift Testing coverage exists for the engine loop, clocks, world builder,
    spawn seeding, movement, rotation, rotation codability/equality, and several
    capability protocol read paths.

## High-Level Direction

### 1. Keep Protocols

Protocols are staying.

They serve two purposes:

- ergonomic game-level typing (`Ball: Movable`, `Ship: Collidable`, etc.)
- a clean bridge to UI and tooling, where code wants typed objects rather than
  raw component rows

Do not remove the protocol layer unless the project direction changes
deliberately.

### 2. Use `Entity` as a Base Class for Live Objects

The project is trending toward `Entity` as a superclass rather than a protocol.

Intent:

- common identity/lifecycle plumbing lives in one place
- concrete game objects are reference types with stable identity
- capability protocols sit on top of that base class

Important:

- systems should not use these objects in hot loops
- these objects are facades/bridges, not the simulation backend

### 3. ECS Is the Runtime Truth

The world's component stores are authoritative.

Entity classes should read from component stores through protocol default
implementations. They are not meant to duplicate gameplay state as a second
authoritative model.

If future UI code needs current data, prefer:

- live computed accessors backed by component stores
- typed lookup from `EntityID`
- optional object registry or on-demand typed handle reconstruction

### 4. Systems Iterate Stores Directly

This is a key design decision from the conversation:

- systems should iterate `ComponentStore`s directly
- systems should not read/write motion through entity property wrappers inside
  hot loops
- object facades are for gameplay ergonomics, scripting-ish code, UI, and
  selection/inspection flows

If a future system needs `position + velocity`, it should join component stores
directly, not loop over `Entity` objects.

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

If spawn-time data needs to be carried through protocols, prefer small,
practical values such as `initialPosition`, `initialVelocity`, etc. Avoid
introducing multiple nearly identical "spawn/descriptor/snapshot" types unless
there is a concrete need.

Current note: `Entity.InitialState` is a practical common seed bag for transform
and motion data. Do not let it grow into a dumping ground for specialized
gameplay state; prefer concrete entity initializers, world builders, or focused
future spawn helpers for data that is not broadly engine-level.

### 6. Motion Model: Use Contribution Accumulation

The project has moved toward a motion contribution model.

Use `CMotionAccumulator` for per-frame motion inputs:

- `acceleration`: continuous influences that scale with `dt`
- `impulse`: instantaneous velocity changes that do not scale with `dt`

Design intent:

- gameplay systems emit motion contributions
- one integration system updates velocity
- movement system then updates position

Avoid having many systems directly mutate `CVelocity` unless they are doing
explicit override/constraint/collision resolution work.

The runtime-first version of this model is aggregate accumulation, not a
per-entity heap of arbitrary contribution objects. If source-level contribution
tracking is ever needed for debugging, add that separately.

The angular equivalent is `CAngularMotionAccumulator`:

- `angularAcceleration`: continuous rotational influences that scale with `dt`
- `angularImpulse`: instantaneous angular velocity changes

`SMovement` and `SRotation` currently combine contribution integration and
transform advancement. If collision, constraints, or staged scheduling become
substantial, consider splitting those phases while preserving the same
accumulator semantics.

## Deep-Dive Notes From Current Code

### Spawn Flow Is Capability-Driven

`World.add(_:from:)` is now the boundary where entity protocol conformances turn
into component rows. Keep capability defaults centralized there so concrete
entities stay ergonomic and do not duplicate ECS row construction.

Calling `add` again for the same live entity currently replaces rows. Treat it
as spawn-time registration unless a future explicit reset/reseed operation is
introduced.

### Generation Safety Is Partially Implemented

`ComponentStore` lookups use `entity.index` for the sparse lookup but then
confirm the full `EntityID`, including generation. That protects reads from
stale generations.

However, the store does not yet remove or compact dense rows. If a future free
list reuses indices with incremented generations, old dense rows can remain in
`entities` and still be visited by direct iteration. Before enabling index
reuse, implement component removal/compaction and add tests for stale-generation
iteration behavior.

### Facades Are Live Handles

Entity objects hold an `unowned` world reference and computed protocol accessors
fatal-error when required backing rows are missing. That is acceptable for
strict live game objects, but UI inspection or editor tooling may eventually
need optional, non-crashing lookup APIs.

### Engine Loop Boundaries Are Clear

`Engine` owns fixed-step accumulation and ordered system execution. `GameLoop`
is the app-level driver that polls wall time on the main actor. Keep wall-clock
sampling, app lifecycle, and session rebuild policy above `Engine` so the core
engine remains easy to test.

The fixed-step loop does not yet have overload protection. If large deltas
become possible, prefer explicit max-step/backlog policy over silently running
unbounded catch-up work.

### Rendering Docs Are Directional

The DocC render articles are proposed architecture, not implemented code. Their
important constraint is still sound: keep backend-specific Metal state out of
`World`; store only abstract presentation state or handles in ECS; extract a
flat render frame for the renderer.

### Documentation Can Drift Quickly

The code has already moved past earlier examples such as `Missile` and
`CAcceleration`. When editing docs or contributor guidance, check current source
names first and update examples to match durable concepts rather than stale
placeholder types.

## Guidance for Future Changes

- Do not reintroduce a global static world lookup model.
- Do not reintroduce a closed enum registry for component identity.
- Keep component storage per-type.
- Keep systems data-oriented.
- Keep `World.add(_:from:)` as a capability-to-component boundary unless a
  clearly better spawn API replaces it.
- Add explicit contribution APIs when needed instead of making many systems or
  object facades directly overwrite integrated velocity.
- Comment executable logic generously. If a method does real work, prefer a
  short doc comment plus inline comments at the important steps so control flow
  and state changes are obvious when reading the code.
- When the user asks for ideas, architecture notes, or future direction to be
  captured for later, prefer adding or updating DocC content under
  `Engine2/Engine2.docc/` rather than leaving that intent only in chat or code
  comments.
- For not-yet-implemented direction, mark the DocC content clearly as proposed
  or future work, and link new conceptual articles from the DocC landing page
  when they represent durable engine design.
- Preserve or improve `EntityID.generation` semantics.
- Do not reuse an entity index until component removal and dense iteration
  behavior are generation-safe.
- Prefer adding capability protocols over deepening inheritance.
- Keep the game-object layer ergonomic, but keep the ECS layer authoritative.
- If adding selection/UI inspection, typed lookup by `EntityID` is a valid
  direction.
- Mirror the app/source tree under `Engine2Tests/`. For example, tests for
  `Engine2/System/SMovement.swift` should live in
  `Engine2Tests/System/SMovementTests.swift`.

## Current Gaps / Known TODOs

- Entity destruction, index reuse, and generation incrementing are not
  implemented.
- `ComponentStore` still needs removal, dense compaction, richer mutation/query
  helpers, and explicit tests for stale-generation behavior.
- Systems still run in one ordered list; the DocC scheduling graph/stage model
  is proposed, not implemented.
- `SMovement` and `SRotation` currently combine integration and transform
  advancement; the future collision/constraint pipeline may need a more explicit
  phase split.
- Rendering extraction, render resources, and presentation buffers are only
  documented direction.
- Capability accessors are strict live reads with `fatalError`; optional
  inspection/editor lookup paths do not exist yet.
- Tests do not yet cover component removal, dense iteration with stale
  generations, `Positionable`/`Movable` protocol reads directly, spawn
  precondition failures, or fixed-step overload policy.

## Working Assumption for Contributors

When in doubt, choose the simpler design that preserves:

- typed game objects at the API boundary
- component stores as runtime truth
- systems as the place where simulation work happens

That is the core intent this repo is trying to protect.
