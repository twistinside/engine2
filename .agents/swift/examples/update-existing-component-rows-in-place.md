# Update Existing Component Rows in Place

An ECS system that has already established that a component row exists should mutate that row through the store's
update API. Reserve insertion for registration, adding a missing component, or a deliberate upsert.

This distinction matters most in hot paths. It avoids routing ordinary field changes through structural storage logic,
communicates the system's invariant, and gives the store a focused mutation path that can be optimized independently.

## Avoid

`SRotation` has already read the required rows and derived their new values, but routes those established rows through
insertion:

```swift
world.angularVelocityComponents.insert(
    CAngularVelocity(angularVelocity: updatedAngularVelocity),
    for: entity
)
world.rotationComponents.insert(CRotation(rotation: updatedRotation), for: entity)

if world.angularMotionAccumulatorComponents[entity] != nil {
    world.angularMotionAccumulatorComponents.insert(zeroAccumulator, for: entity)
}
```

The successful lookups already prove the angular-velocity and rotation rows exist, yet `insert` expresses
add-or-replace semantics when creation is not valid system behavior. The accumulator also performs a separate existence
lookup before the upsert performs its own lookup.

The code also obscures an important system invariant: this phase updates rows created during entity registration; it
must not change which components the entity owns.

## Prefer

```swift
world.angularVelocityComponents.update(for: entity) { angularVelocity in
    angularVelocity = CAngularVelocity(angularVelocity: updatedAngularVelocity)
}
world.rotationComponents.update(for: entity) { rotation in
    rotation = CRotation(rotation: updatedRotation)
}
world.angularMotionAccumulatorComponents.update(for: entity) { accumulator in
    accumulator = zeroAccumulator
}
```

`update(for:_:)` performs the exact-entity lookup and mutates the aligned dense slot through `inout`. A missing
accumulator is a no-op, matching the previous conditional behavior without a separate existence lookup. When a component
exposes mutable fields, update only those fields instead of replacing the complete value:

```swift
world.motionComponents.update(for: entity) { motion in
    motion.velocity = updatedVelocity
    motion.accumulator = .zero
}
```

Prefer driving iteration from one required component store, checking any other required rows, and then using
`update(for:_:)` for every established row changed by the system. This keeps mutation local to the dense storage and
leaves structural changes at explicit registration or lifecycle boundaries.

The current `insert` and `update` implementations both begin with a sparse lookup and exact-identity validation. In the
example above, the concrete lookup saving is removal of the accumulator's separate existence check. Field-level mutation
may also avoid complete-value reconstruction, but measure that effect rather than assuming it. The primary benefit is an
explicit nonstructural invariant and a mutation path that can later accept dense indices or joined rows without changing
system semantics.

## Use Insertion for Structural Changes

`insert(_:for:)` remains appropriate when:

- registering an entity's initial component rows;
- adding an optional component that may not exist;
- intentionally replacing-or-creating a row through upsert semantics;
- reconstructing storage from a trusted snapshot or persistence boundary.

Do not mechanically replace every insertion. The rule is to separate structural ECS changes from hot-path mutation and
choose the API that states which operation is intended.
