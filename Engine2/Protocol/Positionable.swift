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
        guard let positionComponents = WPrimary.components[.position] as? [CPosition] else {
            fatalError("Couldn't find positions for entities.")
        }
        guard id.index < positionComponents.count else {
            fatalError("Couldn't find position for entity: \(self.id)")
        }
        return positionComponents[id.index].position
    }
}
