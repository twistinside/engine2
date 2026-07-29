# Package Architecture

Engine2 uses local Swift packages to enforce the dependency boundaries between
the reusable engine, consumer Game Content, concrete Runtime Assemblies, and the
App composition root.

## Implemented Package Graph

The repository currently vends these library products:

| Product | Responsibility |
| --- | --- |
| `Engine2` | Reusable Input, Simulation, Render, ECS, UI-adapter, and Metal implementation |
| `Engine2GPUABI` | C declarations shared by Swift and Metal shader code |
| `BasicGameContent` | Example entities, world construction, authored Simulation policy and render catalogs, and packaged assets |
| `Engine2AssemblySupport` | Common `PRuntimeAssembly` hosting and injected-construction boundary plus the narrow `PGameContent` seam |
| `Engine2RealtimeAssembly` | Interactive Input, fixed-step Simulation, screen Render, snapshot capture, lifecycle, and App UI topology |
| `Engine2ManualAssembly` | Caller-driven Simulation and screen Render topology without Input or automatic cadence |
| `Engine2OfflineCaptureAssembly` | Closed exact advance-or-current capture, offscreen Render, and artifact-encoding topology |
| `Engine2AgentSessionAssembly` | Transport-neutral live agent session that wraps the complete offline-capture topology |

Their enforced dependencies are:

```text
Engine2App
├── Engine2AssemblySupport
│   └── Engine2
├── BasicGameContent
│   ├── Engine2AssemblySupport
│   └── Engine2
└── Engine2RealtimeAssembly
    ├── Engine2AssemblySupport
    └── Engine2

Engine2ManualAssembly ──────────┬──> Engine2AssemblySupport
                               └──> Engine2

Engine2OfflineCaptureAssembly ──┬──> Engine2AssemblySupport
                               └──> Engine2

Engine2AgentSessionAssembly ───┬──> Engine2OfflineCaptureAssembly
                               ├──> Engine2AssemblySupport
                               └──> Engine2
```

`Engine2AssemblySupport` depends on `Engine2` because `PGameContent` names the
world builder, Simulation configuration, and Render catalog supplied during
assembly construction. `PRuntimeAssembly` accepts that content and refines
SwiftUI `View`; each assembly body owns any topology-specific presentation
lifecycle. Neither protocol is a universal Runtime service container: the
content seam carries only immutable construction inputs, and the assembly
protocol grants no topology-specific Runtime authority.

The agent-session product deliberately depends on the offline-capture product.
`AgentSessionAssembly` privately retains one complete
`OfflineCaptureAssembly`; it does not rebuild or bypass that assembly's sole
effective Simulation advance authority.

## The App Is the Composition Root

The Xcode App target contains only application resources and
`Engine2App`. It imports `Engine2AssemblySupport` and the selected concrete
assembly product plus its selected Game Content product. It constructs Game
Content, injects it through `PRuntimeAssembly.init(gameContent:)`, retains the
assembly behind `some PRuntimeAssembly`, and presents it directly.

Changing the selected topology is therefore an outer composition decision. The
App does not import the selected assembly's private Runtime graph or recreate
its wiring. A different executable can select another assembly product, and an
engine consumer can provide a new assembly package without modifying the
reusable engine package.

## Game Content Depends on Engine Contracts

`BasicGameContent` is an example consumer package. It imports `Engine2` for
engine contracts and `Engine2AssemblySupport` to conform to `PGameContent`. It
provides:

- the `Ball` entity facade
- `BasicWorldBuilder`
- the complete `.basicGame` Simulation configuration
- the complete `.everything` render catalog
- `Ball.usda` and `Ball.usdz` as package resources

The dependency points inward: the reusable `Engine2` package and concrete
assembly packages do not import `BasicGameContent`. The App selects that
consumer package and passes its `PGameContent` value to the selected assembly.

## Asset Identities Cross Through Engine-Owned Keys

Game Content owns the exhaustive, strongly typed `MeshID` and `MaterialID`
enums for its authored catalog. The reusable engine cannot store those enum
types without depending back on the consumer package, which would create a
package cycle.

Each Game Content enum therefore projects to an engine-owned transport key:

```swift
MeshID.ball.assetKey
MaterialID.goldMetal.assetKey
```

`MeshAssetKey` and `MaterialAssetKey` cross ECS, snapshot, and Render
boundaries. `RenderAssetCatalog` maps those keys to the exact model URLs and
material descriptions supplied by the selected Game Content package.

The selected catalog defines each key namespace. Callers must not combine keys
from independently authored catalogs until the architecture adds an explicit
catalog identity.

This split preserves two properties:

- Game Content retains exhaustive enums for authored choices.
- Engine contracts remain package-neutral and reusable across consumers.

The keys are not a replacement for closed Game Content enums and should not
become an untyped global asset registry.

## Assembly Packages Own Topology-Specific Code

Each concrete Runtime Assembly has its own package. Its package owns the
Runtime instances, drivers, coordinators, focused policy and limit values,
topology-local UI, and lifecycle policy required by that graph. Assemblies
accept those values directly; there is no layer of forwarding wrappers or
assembly factories.

Shared code moves inward only when two assemblies need the same capability and
the capability has one coherent owner. The current shared layers are:

- `Engine2AssemblySupport` for App hosting and the narrow Game Content
  construction contract
- `Engine2` for reusable Runtime, ECS, Render, and adapter implementation
- `BasicGameContent` for example consumer content selected by the App
- `Engine2OfflineCaptureAssembly` as a complete dependency of
  `Engine2AgentSessionAssembly`

Do not create a shared package merely to avoid a small amount of similar
topology policy. Moving code inward broadens the set of dependents that can
reach it and must preserve its ownership and lifecycle meaning.

## Package Boundaries Are Architectural Tests

The package graph prevents several invalid dependencies at compile time:

- Engine implementation cannot name Basic Game Content entities or enums.
- Game Content cannot reach assembly-private lifecycle or coordination state.
- One assembly cannot reach another assembly's internals unless it declares an
  explicit package dependency.
- The App cannot bypass a selected assembly's topology through transitive
  imports.
- Shared Swift and Metal records remain in the dedicated `Engine2GPUABI`
  target instead of relying on an App bridging header.

`internal` remains the default implementation boundary inside each module.
Make an API `public` only when an importing package needs a supported contract;
do not expose storage, scheduler, or backend details merely to preserve
same-target access that existed before the package split.

## Distribution Remains a Separate Decision

The current manifests use sibling path dependencies inside one checkout. They
enforce local build boundaries and let Xcode compose the products, but a remote
SwiftPM dependency cannot select an arbitrary nested manifest from this Git
repository. Publishing these packages will require an explicit distribution
shape, such as separate package repositories with URL dependencies or one
aggregate root manifest that vends the supported products. That decision does
not weaken the dependency rules exercised by the current local graph.

## Related Architecture

- <doc:Game-Content-Architecture>
- <doc:Runtime-Architecture>
- <doc:Runtime-Assemblies-and-Advancement>
- <doc:Runtime-Communication>
- <doc:Rendering-Architecture>
