# Swift coding preferences

When working in Swift:

- Write idiomatic modern Swift rather than translating C++, Java, or traditional game-engine patterns.

- Prefer value semantics unless reference identity is required.

- When `SWIFT_DEFAULT_ACTOR_ISOLATION` supplies an actor, omit redundant explicit actor annotations from
  declarations that inherit it. Keep actor-qualified closure types, deliberate actor re-entry annotations, and
  actor-isolated members whose enclosing type is explicitly `nonisolated`, or protocol conformances whose isolation
  must be stated to preserve the intended witness boundary.

- Prefer standard Swift language features over custom abstractions.

- Use the shared floating-point `SIMD` classification properties for whole-vector validation instead of repeating
  per-lane checks. `isFinite`, `isNormal`, and `isZero` require every lane to satisfy the classification; `isInfinite`,
  `isNaN`, `isSignalingNaN`, and `isSubnormal` report whether any lane has that exceptional classification.

- Use 120 characters as the ordinary line-length limit. A modest overrun is preferable when wrapping one cohesive
  string, declaration, method signature, enum case, pattern, or call would make it harder to scan—especially when one
  readable line would become three or four. Break lines for semantic grouping, not merely to satisfy a counter.

- Declare every stored and computed property before all initializers, subscripts, and methods in the same declaration
  or extension. A computed projection remains part of the type's state surface even when its implementation is long;
  do not tuck it beneath an initializer or behavioral method.

- Spell an empty array with an explicit declaration type and an empty literal, such as
  `var instances: [RenderInstance] = []`, rather than inferring the type from `[RenderInstance]()`.

- Extract a constructed value when the local adds a nonredundant role, exposes validation or reuse, or separates a
  substantial construction from the operation that consumes it. Otherwise, keep construction inline when an argument,
  property, or enum case label already states the role, direct assignment or initializer delegation is clearer, or a
  tuple, collection, or builder should read as one aggregate. A label does not erase a separate ownership, validation,
  reuse, or substantial construction decision. Do not add a local that merely repeats nearby syntax. Apply the same
  judgment to `SIMD` values and small domain wrappers; initializer syntax alone does not require extraction.

- Use Swift's synthesized initializers when they express the intended construction API. Do not write a structure
  initializer that only assigns same-named parameters to stored properties. Keep an explicit initializer when it
  validates, normalizes, delegates, changes labels or access, supplies deliberate defaults, satisfies a protocol
  requirement, or is needed because another initializer suppresses the desired synthesis.

- Put a secondary behavioral protocol conformance with handwritten requirements in a focused extension when possible,
  keeping its implementation with the conformance. Defining-role, inheritance, marker, and synthesized conformances may
  remain on the primary declaration when a separate extension would add no useful organization.

- Keep every extension with the type it extends. For a repository-owned type, put the extension in that type's owning
  file; never place an extension of one repository type in another type's file. Put an extension of a framework or other
  externally owned type in its own appropriately named file under `Extension/`. Do not create a separate extension file
  solely for one static member: keep that member with the repository type's primary declaration.
  Test-target-only support is an exceptional case when moving it would expose fixture API in production; keep that
  extension in a clearly named test-support file and document why it cannot live with the production declaration.

- Use `static` only for a genuinely type-level value or operation. Do not use static helper methods as an
  implementation-detail namespace. Keep helpers that support one instance's workflow as instance methods even when they
  do not currently read stored state, and keep one-use calculations inline when extraction adds no domain meaning.

- Within one concrete implementation, prefer throwing methods that return only their successful value. Do not introduce
  request, response, result, outcome, or completion types merely to carry local success and failure between adjacent
  calls. Keep explicit value-shaped outcomes at real runtime, actor, protocol, persistence, replay, or transport
  boundaries when admission, cancellation, provenance, partial commitment, or exhaustive handling is part of the
  contract. Use typed throws when the implementation has one closed error domain and its dependencies can preserve that
  type without artificial wrapping. Swift calls this feature "typed throws," not "checked exceptions."

- Resolve required fallible resources at their owning construction boundary. Convert string or external identities into
  validated typed handles once, retain them, and make downstream access nonthrowing when successful construction proves
  they exist. Defer creation only when identity, availability, size, or deliberate demand-driven cost is genuinely
  dynamic.

- When designing or substantially rewriting Swift code, consult the relevant examples under `.agents/swift/examples/`.
