//
//  CVelocity.swift
//  Engine2
//
//  Created by Karl Groff on 3/8/26.
//

struct CVelocity: Component {
    static let type: ComponentType = .velocity
    
    let velocity: SIMD3<Float>
}
