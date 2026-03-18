//
//  WorldBuilder.swift
//  Engine2
//
//  Created by Codex on 3/17/26.
//

/// Minimal concrete builder used by the app and simple tests.
///
/// The default world starts with one ball so the bootstrap path exercises the
/// normal entity-to-component creation flow.
struct BasicWorldBuilder: WorldBuilder {
    func buildWorld() -> World {
        let world = World()

        _ = Ball(in: world)

        return world
    }
}
