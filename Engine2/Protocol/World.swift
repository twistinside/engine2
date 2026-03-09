//
//  World.swift
//  Engine2
//
//  Created by Karl Groff on 3/8/26.
//

protocol World {
    static var components: [ComponentType: [any Component]] { get }

    func update(delta: Double)
}
