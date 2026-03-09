//
//  System.swift
//  Engine2
//
//  Created by Karl Groff on 3/8/26.
//

protocol System {
    mutating func update(world: inout World, deltaTime: Float)
}
