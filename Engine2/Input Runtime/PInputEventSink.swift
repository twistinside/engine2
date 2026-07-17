//
//  PInputEventSink.swift
//  Engine2
//
//  Created by Codex on 7/16/26.
//

/// Receives platform-neutral events from an input host adapter.
@MainActor
protocol PInputEventSink: AnyObject {
    func receive(_ event: InputEvent)
}
