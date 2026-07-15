//
//  PComponent.swift
//  Engine2
//
//  Created by Karl Groff on 3/8/26.
//

/// Marker for plain ECS component values.
///
/// Components and their `Codable`/`Equatable` witnesses are intentionally
/// independent of the app target's default actor isolation. Runtime ownership
/// controls access to component stores; the value types themselves do not
/// require the main actor.
nonisolated protocol PComponent: Codable, Equatable {}
