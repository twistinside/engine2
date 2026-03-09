//
//  Positionable.swift
//  Engine2
//
//  Created by Karl Groff on 3/8/26.
//

protocol Positionable: Entity {
    var position: SIMD3<Float> { get }
}

extension Positionable {
    var position: SIMD3<Float> {
        guard let position = world.positionComponents[self.id]?.position else {
            fatalError("There is no position for the positionable entity with ID: \(self.id)")
        }
        return position
    }
}
