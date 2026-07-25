# Prefer Inline Validation Over One-Use Helpers

When a calculation is used in one place and its validation is straightforward,
keep the calculation and validation together. Do not introduce a type-scoped
helper merely to wrap one expression, convert a Boolean validity check into an
optional, or make the call site artificially concise.

## Avoid

```swift
if let yawDelta = Self.finiteProduct(
    pointerMotion.x,
    pointerOrbitSensitivity
), yawDelta != 0 {
    directives.append(.orbitCamera(yawDelta: yawDelta))
}

private static func finiteProduct(
    _ lhs: Float,
    _ rhs: Float
) -> Float? {
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
let yawDelta = pointerMotion.x * pointerOrbitSensitivity
if yawDelta.isFinite && yawDelta != 0.0 {
    let directive = SimulationDirective.orbitCamera(yawDelta: yawDelta)
    directives.append(directive)
}
```

The preferred form keeps the data flow visible: calculate the value, validate
it, construct the domain value, and append it. No optional or helper is needed.

Extract a private method when the operation has meaningful domain semantics or
is reused enough that a name clarifies intent. Prefer an extension when the
operation naturally belongs to another type and is useful in more than this
single call site. Otherwise, favor clear inline code and an ordinary guard or
`if` statement.
