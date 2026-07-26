# Prefer Inline Validation Over One-Use Helpers

When a calculation is used in one place and its validation is straightforward,
keep the calculation and validation together. Do not introduce a type-scoped
helper merely to wrap one expression, convert a Boolean validity check into an
optional, or make the call site artificially concise.

## Avoid

```swift
let cameraOrbitYawDelta = Self.finiteProduct(
    world.input.mouse.delta.x,
    pointerOrbitSensitivity
)
world.input.actions.cameraOrbitYawDelta = cameraOrbitYawDelta ?? 0

private static func finiteProduct(_ lhs: Float, _ rhs: Float) -> Float? {
    let product = lhs * rhs
    return product.isFinite ? product : nil
}
```

This version:

- introduces indirection for logic used only once;
- creates an optional even though absence is not part of the domain model;
- uses optional binding to express a simple Boolean validation;
- separates the calculation from the conditions that determine whether its
  result should be used;
- makes the helper concise at the expense of making the complete behavior
  harder to read.

## Prefer

```swift
let cameraOrbitYawDelta = world.input.mouse.delta.x * pointerOrbitSensitivity
world.input.actions.cameraOrbitYawDelta = cameraOrbitYawDelta.isFinite ? cameraOrbitYawDelta : 0
```

The preferred form keeps the data flow visible: calculate the value, validate
it, and assign the transient semantic action. No optional or helper is needed.

Extract a private method when the operation has meaningful domain semantics or
is reused enough that a name clarifies intent. Prefer an extension when the
operation naturally belongs to another type and is useful in more than this
single call site. Otherwise, favor clear inline code and an ordinary guard or
`if` statement.

Static is not the default home for implementation helpers. When a reusable
helper supports one instance's behavior, prefer an instance method even if the
current implementation reads only its arguments. Reserve a static method for
behavior callers should conceptually invoke on the type itself. See
[genuine static processes](choose-the-right-construction-api.md#use-a-static-function-for-a-genuine-process)
for one such exception.
