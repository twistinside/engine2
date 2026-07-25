# Require Explicit Behavior-Affecting Values

Default argument values should be rare. Make the caller provide values that
affect simulation, timing, physics, input response, limits, persistence, or
other application behavior.

Injection establishes one deliberate source of configuration. Adding defaults
to the injected initializer weakens that boundary: a caller can accidentally
omit a value, silently select local policy, and become inconsistent with the
rest of the application.

## Avoid

```swift
struct DefaultInputDirectiveMapper {
    let pointerOrbitSensitivity: Float
    let scrollZoomSensitivity: Float

    init(
        pointerOrbitSensitivity: Float = 0.01,
        scrollZoomSensitivity: Float = 0.04
    ) {
        self.pointerOrbitSensitivity = pointerOrbitSensitivity
        self.scrollZoomSensitivity = scrollZoomSensitivity
    }
}
```

The defaults make construction convenient, but they also make it easy for one
call site to forget the shared configuration. Sensitivity affects observable
Simulation behavior, so every production construction path should receive the
same deliberately selected values.

The same concern applies to values such as:

- fixed tick duration;
- movement, rotation, or camera sensitivity;
- physics constants and tolerances;
- retry, timeout, and buffering limits;
- retention and resource budgets;
- encoding or quality policy.

## Prefer

```swift
struct DefaultInputDirectiveMapper {
    let pointerOrbitSensitivity: Float
    let scrollZoomSensitivity: Float

    init(
        pointerOrbitSensitivity: Float,
        scrollZoomSensitivity: Float
    ) {
        self.pointerOrbitSensitivity = pointerOrbitSensitivity
        self.scrollZoomSensitivity = scrollZoomSensitivity
    }
}

let mapper = DefaultInputDirectiveMapper(
    pointerOrbitSensitivity: inputConfiguration.pointerOrbitSensitivity,
    scrollZoomSensitivity: inputConfiguration.scrollZoomSensitivity
)
```

This makes the dependency visible and requires the composition root to select
the policy. Missing configuration becomes a compile-time error instead of a
silent behavioral difference.

## Convenience Initializers

In Swift, `convenience init` has a specific meaning. It is available only on
classes, must delegate to another initializer on the same class, and must
ultimately reach a designated initializer. It is not a synonym for a static
factory method or any initializer that happens to be shorter.

A convenience initializer is useful when callers must still provide the values
that identify or connect an object, while the initializer supplies a common
default for state that belongs independently to that object.

```swift
final class Ball {
    let world: World
    var position: SIMD3<Float>

    init(
        in world: World,
        position: SIMD3<Float>
    ) {
        self.world = world
        self.position = position
    }

    /// Spawns this Ball at the neutral origin. Position belongs only to this
    /// Ball, so choosing the origin does not establish policy for other entities.
    convenience init(in world: World) {
        self.init(
            in: world,
            position: .zero
        )
    }
}
```

This convenience initializer has a coherent role:

- the initializer is an actual class convenience initializer;
- it delegates to the designated initializer instead of duplicating setup;
- the caller must still provide the Ball's owning `World`;
- the omitted position has a natural neutral value;
- position is local to one Ball and may legitimately differ between entities;
- the documentation explains why the supplied value is safe.

Common backing storage or a standard handler can follow the same pattern when
each instance may independently choose another implementation through the
designated initializer. If every instance must use the same storage, handler,
or policy for correctness, it belongs in shared configuration and must remain
explicitly injected.

Sensitivity is not like a Ball's initial position:

```swift
// Avoid: this silently lets individual mappers select different app policy.
convenience init() {
    self.init(
        pointerOrbitSensitivity: 0.01,
        scrollZoomSensitivity: 0.04
    )
}
```

Orbit and zoom sensitivities will normally need to agree throughout the
application. Omitting them from a call site makes inconsistent construction
easy, regardless of whether the omission uses default arguments or a real
convenience initializer.

Structures and enumerations do not have convenience initializers. They may
define additional initializers and delegate with `self.init`, but those are
still ordinary initializers. Do not replace them with a static factory merely
to imitate class convenience-initializer syntax.

The Swift Book's `RecipeIngredient` example follows the same shape: callers
still provide the ingredient's name, while a convenience initializer supplies
the common per-instance quantity. See
[Designated and Convenience Initializers in Action](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/initialization/#Designated-and-Convenience-Initializers-in-Action)
for the complete example and the language's delegation rules.

Do not add defaults merely to shorten call sites or preserve source
compatibility. A convenience initializer is not an exemption from configuration
consistency. Ask whether each instance may safely choose the omitted value
independently. If the value must agree across objects or subsystems, require
explicit injection from shared configuration.

For the distinction between full initializers, class convenience initializers,
named static values, factories, and default arguments, see
[Choose the Construction Form That Expresses Intent](choose-the-right-construction-api.md).
