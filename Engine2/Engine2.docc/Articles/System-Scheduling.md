# System Scheduling
This article captures the intended scheduling direction for Engine2.
## Status
Partially implemented. Parts of this model are not implemented yet.
The current engine already runs two ordered system lists:
- always-running systems for input and tooling
- simulation-gated systems for gameplay state advancement

The default gameplay order is currently `SAccelerationIntent`, ``SMovement``,
`SSphereCollision`, then `SRotation`. Collision runs after movement so it sees
the completed positions for the fixed step and can correct overlap before the
next step begins. This explicit array order is the current implementation, not
yet scheduler metadata.
The ideas below describe the intended next layer of scheduling behavior as the engine becomes more complex.

ECS systems and this scheduler live inside the authoritative Simulation Runtime. A system is scheduled simulation logic, not a top-level runtime. See <doc:Runtime-Architecture> for that distinction.
## Non-Reentrant Updates
Only one simulation update should be in flight at a time.
When the clock produces new elapsed time, the engine should treat that as additional backlog, not permission to begin another overlapping world update. If the engine is already stepping systems, newly arrived time should be accumulated and drained later.
This keeps world mutation serialized even if clock delivery and future worker execution become more sophisticated.
## Dependency Graph
The intended long-term scheduler model is a dependency graph built from system metadata.
Each system is expected to eventually declare:
- which components or resources it reads
- which components or resources it writes
- optional explicit ordering constraints such as "runs before" or "runs after"
From that metadata, the scheduler can derive edges such as:
- writer to reader
- reader to writer
- writer to writer
- explicit before/after ordering
An edge means "must run before." If the resulting graph contains a cycle, scheduling should fail loudly instead of silently choosing an arbitrary order.
## Ordered Stages
The dependency graph can be reduced into execution stages.
Within a stage:
- systems have no unmet dependencies on one another
- systems are candidates to run in parallel
Between stages:
- a barrier exists
- all work in the earlier stage must finish before the next stage begins
This staged model is the intended way to preserve deterministic ordering while still allowing parallel execution where safe.
## Phase Thinking
Not every dependency needs to be expressed as a hand-written edge.
It is useful to think in coarse simulation phases, then let the dependency graph provide finer ordering inside those phases. Likely phases include:
- input interpretation
- gameplay contribution
- detection
- resolution
- integration
- movement
- cleanup
- presentation or export
The exact phase list is expected to evolve with the engine.
Only the export side of presentation belongs in the simulation schedule. Actual rendering and Metal submission should happen after export, from the frozen presentation data, rather than as a world-mutating system.
## Cadence
Some systems should not need to run every simulation tick.
Examples include:
- AI planning
- inference
- expensive perception queries
The intended direction is to represent this as scheduler metadata, such as:
- every tick
- every N simulation ticks
- every T seconds of simulation time
- on demand
Cadence should be defined in simulation-tick terms rather than render-frame terms so behavior stays deterministic under a fixed-step engine.
## Background Work
Expensive AI or inference should not mutate ``World`` directly from background threads.
The preferred direction is:
1. capture the required world state as an immutable work payload
2. run the expensive work off-thread
3. apply the result back to the world during a later scheduled simulation tick
That keeps authoritative world mutation inside the scheduler while still allowing expensive computation to happen elsewhere.
## Topics
### Architecture
- <doc:Runtime-Architecture>
### Related Symbols
- ``Engine``
- ``World``
- ``PSystem``
- ``SMovement``
- `SSphereCollision`
