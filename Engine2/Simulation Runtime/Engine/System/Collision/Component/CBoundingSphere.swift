//
//  CBoundingSphere.swift
//  Engine2
//
//  Created by Codex on 7/15/26.
//

/// Coarse spherical collision bound centered on an entity's position.
///
/// The first collision pass treats every sphere as a unit-mass solid. Shape
/// offsets, layers, triggers, mass, and material response remain future work.
struct CBoundingSphere: PComponent, Equatable {
    let radius: Float

    init(radius: Float) {
        precondition(
            radius.isFinite && radius > 0,
            "A bounding-sphere radius must be finite and positive."
        )
        self.radius = radius
    }
}
