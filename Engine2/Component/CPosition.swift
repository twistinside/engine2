//
//  CLocation.swift
//  Engine2
//
//  Created by Karl Groff on 3/8/26.
//

struct CPosition: Component {
    static let type: ComponentType = .position

    let position: SIMD3<Float>
}
