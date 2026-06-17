//
//  POrientable.swift
//  Engine2
//
//  Created by Codex on 3/15/26.
//

import simd

protocol POrientable: Entity {
    var rotation: simd_quatf { get }
}

extension POrientable {
    var rotation: simd_quatf {
        guard let rotation = world.rotationComponents[self.id]?.rotation else {
            fatalError("There is no rotation for the rotatable entity with ID: \(self.id)")
        }
        return rotation
    }
}
