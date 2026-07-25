# Avoid Static Factories for Ordinary Construction

Do not wrap a straightforward synchronous initializer in a static factory
method merely to hide arguments, provide defaults, or make construction look
more descriptive.

## Avoid

```swift
extension DefaultInputDirectiveMapper {
    /// Test-only camera binding with fixed values chosen for deterministic
    /// fixture setup. Production composition must inject shared configuration.
    static func testFixture() -> Self {
        Self(
            pointerOrbitSensitivity: 0.01,
            scrollZoomSensitivity: 0.04
        )
    }
}
```

This is not a Swift convenience initializer. It is an ordinary type method that
returns a newly initialized value.

The wrapper is harmful here because it:

- disguises behavior-affecting initializer arguments;
- introduces another construction API without adding construction semantics;
- makes call sites look intentionally configured when they actually select
  hidden values;
- encourages ad hoc factories for previews, tests, and production;
- uses a method where Swift's initializer syntax already expresses the work.

## Prefer Explicit Construction

```swift
let mapper = DefaultInputDirectiveMapper(
    pointerOrbitSensitivity: 0.01,
    scrollZoomSensitivity: 0.04
)
```

Keep fixture construction in the fixture setup so the selected values remain
visible. If several tests share the same setup, centralize the configuration
data or the complete fixture at the appropriate test-suite boundary instead of
adding a production type method that conceals policy.

For a class, a real `convenience init` may be appropriate when it is a justified
secondary initialization path. It must delegate to another initializer on the
same class and ultimately reach a designated initializer. Structures and
enumerations do not support `convenience init`; do not imitate it with a static
factory.

A static factory is appropriate only when it communicates semantics that an
initializer cannot honestly express—for example, returning a cached instance,
choosing a concrete implementation behind an abstract result, or performing a
distinct construction process. Document that reason. Do not use one as an
initializer alias.

A named static value is different from a static factory. Use a property such as
`.everything` when the API exposes one stable, distinguished value rather than
performing a construction process. See
[Choose the Construction Form That Expresses Intent](choose-the-right-construction-api.md).

See
[Designated and Convenience Initializers in Action](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/initialization/#Designated-and-Convenience-Initializers-in-Action)
for Swift's initializer delegation rules.
