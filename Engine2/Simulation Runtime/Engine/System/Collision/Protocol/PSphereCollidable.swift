//
//  PSphereCollidable.swift
//  Engine2
//
//  Created by Codex on 7/15/26.
//

/// Entity capability that seeds and exposes a position-centered bounding sphere.
protocol PSphereCollidable: PPositionable {
    /// Game Content's spawn-time collision radius.
    var initialBoundingSphereRadius: Float { get }

    /// Live collision radius backed by the world's component store.
    var boundingSphereRadius: Float { get }
}
extension PSphereCollidable {
    var boundingSphereRadius: Float {
        guard let sphere = world.boundingSphereComponents[id] else {
            fatalError(
                "There is no bounding sphere for the collidable entity with ID: \(id)"
            )
        }

        return sphere.radius
    }
}
