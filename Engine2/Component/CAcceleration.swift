//
//  CAcceleration.swift
//  Engine2
//
//  Created by Karl Groff on 3/8/26.
//

struct CAcceleration: Component {
    static let type: ComponentType = .acceleration

    let acceleration: SIMD3<Float>
}
