# Engine2 AGENTS Guide

## Repo Summary

Engine2 is a first-pass Swift ECS experiment with an intentionally small codebase.
The project is moving toward a hybrid model:

- ECS component stores are the runtime source of truth.
- Entity objects are ergonomic, typed facades over ECS state.
- Capability protocols such as `Movable` and `Positionable` are kept as the
  game-facing/UI-facing surface.
- Systems should operate directly on component stores in hot paths.

This repo is still early and partially skeletal. Preserve direction and intent
when filling in missing pieces.

## Current Structure

- `Engine2/World/World.swift`
  - Central world object.
  - Owns component stores.
  - `add(_:)` and `reserveEntityID()` are still placeholders.

- `Engine2/World/Entity.swift`
  - Base `Entity` superclass.
  - Holds `id` and `world`.
  - Current initializer auto-registers with `World`; this is still in flux.

- `Engine2/World/EntityID.swift`
  - Entity handle with `index` and `generation`.
  - `generation` should remain meaningful; do not silently regress to index-only
    identity semantics.

- `Engine2/World/ComponentStore.swift`
  - Sparse-set style storage skeleton:
    - `dense`: component values
    - `entities`: entity IDs aligned with `dense`
    - `sparse`: entity index -> dense index

- `Engine2/Protocol/Component.swift`
  - Marker protocol for components.

- `Engine2/Protocol/Positionable.swift`
  - Convenience protocol for entity objects that can expose a live `position`
    backed by the world component store.

- `Engine2/Protocol/Movable.swift`
  - Convenience protocol for entity objects that can expose live `velocity`,
    `acceleration`, and `impulse` backed by world component stores.

- `Engine2/Component/*.swift`
  - `CPosition`
  - `CVelocity`
  - `CMotionAccumulator`
  - `CAcceleration` currently still exists, but the intended direction is to
    phase it out in favor of `CMotionAccumulator`.

- `Engine2/System/*.swift`
  - Systems are present as placeholders.
  - The intended model is system-driven iteration over component stores, not
    object wrappers.

- `Engine2/Entity/Missile.swift`
  - Example entity object/facade.
  - Represents the intended style of game object API more than a finished
    implementation.

- `Engine2Tests/`
  - Minimal test scaffolding only.

## High-Level Direction

### 1. Keep Protocols

Protocols are staying.

They serve two purposes:

- ergonomic game-level typing (`Missile: Movable`, `Ship: Collidable`, etc.)
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
let missile = Missile(...)
```

or a closely related `spawn`/factory variant.

The important idea is:

- gameplay code should remain ergonomic
- ECS conversion happens at the world boundary

If spawn-time data needs to be carried through protocols, prefer small,
practical values such as `initialPosition`, `initialVelocity`, etc. Avoid
introducing multiple nearly identical "spawn/descriptor/snapshot" types unless
there is a concrete need.

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

## Guidance for Future Changes

- Do not reintroduce a global static world lookup model.
- Do not reintroduce a closed enum registry for component identity.
- Keep component storage per-type.
- Keep systems data-oriented.
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
- Prefer adding capability protocols over deepening inheritance.
- Keep the game-object layer ergonomic, but keep the ECS layer authoritative.
- If adding selection/UI inspection, typed lookup by `EntityID` is a valid
  direction.
- Mirror the app/source tree under `Engine2Tests/`. For example, tests for
  `Engine2/System/SMovement.swift` should live in
  `Engine2Tests/System/SMovementTests.swift`.

## Current Gaps / Known TODOs

- `World.add(_:)` does not yet translate entity capabilities into components.
- `reserveEntityID()` is still a stub.
- `ComponentStore` still needs removal and richer mutation/query helpers.
- Motion integration system is not implemented yet.
- Movement is currently handled in `SMovement`, but the broader motion/collision
  pipeline is still incomplete.
- Tests do not yet cover sparse-set behavior, generation safety, or motion
  integration.

## Working Assumption for Contributors

When in doubt, choose the simpler design that preserves:

- typed game objects at the API boundary
- component stores as runtime truth
- systems as the place where simulation work happens

That is the core intent this repo is trying to protect.
