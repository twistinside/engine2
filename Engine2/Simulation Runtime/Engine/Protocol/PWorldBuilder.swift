//
//  PWorldBuilder.swift
//  Engine2
//
//  Created by Karl Groff on 3/17/26.
//


/// Creates a fully bootstrapped world for a new simulation session or load operation.
protocol PWorldBuilder {
    func buildWorld() -> World
}
