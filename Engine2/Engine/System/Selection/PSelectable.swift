//
//  PSelectable.swift
//  Engine2
//
//  Created by Codex on 5/31/26.
//

protocol PSelectable: Entity {
    var selectionState: CSelectable.SelectionState { get }
}

extension PSelectable {
    var selectionState: CSelectable.SelectionState {
        guard let selectable = world.selectableComponents[self.id] else {
            fatalError("There is no selectable component for the selectable entity with ID: \(self.id)")
        }
        return selectable.selectionState
    }
}
