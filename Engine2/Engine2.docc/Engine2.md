# ``Engine2``

Engine2 is a small ECS-first engine experiment with typed entity facades, per-type component stores, and a fixed-step simulation loop.

## Overview

The current codebase is intentionally small, but the core direction is already established:

- ``World`` owns runtime state.
- ``Engine`` owns fixed-step orchestration and system execution.
- ``System`` implementations operate on component stores, not object facades, in hot paths.
- ``Entity`` subclasses and capability protocols remain the ergonomic game-facing layer.

This documentation catalog serves two purposes:

- document the behavior that already exists in the codebase
- capture architectural direction that is intentionally not implemented yet

## Topics

### Architecture

- <doc:Engine-Architecture>

### Scheduling

- <doc:System-Scheduling>
