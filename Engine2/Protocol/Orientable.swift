//
//  Rotatable.swift
//  Engine2
//
//  Created by Codex on 3/15/26.
//

import simd

protocol Orientable: Entity {
    var rotation: simd_quatf { get }
}

extension Orientable {
    var rotation: simd_quatf {
        guard let rotation = world.rotationComponents[self.id]?.rotation else {
            fatalError("There is no rotation for the rotatable entity with ID: \(self.id)")
        }
        return rotation
    }
}
