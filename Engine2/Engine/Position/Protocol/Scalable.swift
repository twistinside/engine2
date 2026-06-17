//
//  Scalable.swift
//  Engine2
//
//  Created by Codex on 3/15/26.
//

protocol Scalable: Entity {
    var scale: SIMD3<Float> { get }
}

extension Scalable {
    var scale: SIMD3<Float> {
        guard let scale = world.scaleComponents[self.id]?.scale else {
            fatalError("There is no scale for the scalable entity with ID: \(self.id)")
        }
        return scale
    }
}
