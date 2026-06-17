//
//  CSelectable.swift
//  Engine2
//
//  Created by Codex on 5/31/26.
//

/// Selection state for entities that can participate in UI, tooling, or
/// renderer selection feedback.
struct CSelectable: PComponent {
    var selectionState: SelectionState = .unselected

    enum SelectionState: Codable, Equatable {
        case unselected
        case selected
        case highlighted
    }
}
