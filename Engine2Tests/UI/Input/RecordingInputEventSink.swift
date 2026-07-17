//
//  RecordingInputEventSink.swift
//  Engine2Tests
//
//  Created by Codex on 7/16/26.
//

@testable import Engine2

@MainActor
final class RecordingInputEventSink: PInputEventSink {
    private(set) var receivedEvents: [InputEvent] = []

    func receive(_ event: InputEvent) {
        receivedEvents.append(event)
    }
}
