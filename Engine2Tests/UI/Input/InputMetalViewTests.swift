//
//  InputMetalViewTests.swift
//  Engine2Tests
//
//  Created by Codex on 7/15/26.
//

import AppKit
import Testing
@testable import Engine2

struct InputMetalViewTests {
    @MainActor
    @Test func acceptsKeyboardFocusAndTranslatesKeyTransitions() throws {
        let view = InputMetalView(frame: .zero, device: nil)
        // InputMetalView deliberately retains its sink weakly, so the host
        // owns the adapter destination for as long as events may arrive.
        let inputSink = RecordingInputEventSink()
        view.inputSink = inputSink
        let keyDown = try #require(
            makeKeyEvent(type: .keyDown, isRepeat: false)
        )
        let keyUp = try #require(
            makeKeyEvent(type: .keyUp, isRepeat: false)
        )

        view.keyDown(with: keyDown)
        view.keyUp(with: keyUp)

        #expect(view.acceptsFirstResponder)
        #expect(inputSink.receivedEvents.count == 2)

        guard case let .keyDown(downKey) = inputSink.receivedEvents[0],
              case let .keyUp(upKey) = inputSink.receivedEvents[1]
        else {
            Issue.record("Expected key-down followed by key-up events.")
            return
        }

        #expect(downKey == KeyboardKey(keyCode: 13, displayName: "W"))
        #expect(upKey == downKey)
    }

    @MainActor
    @Test func repeatedKeyDownIsIgnored() throws {
        let view = InputMetalView(frame: .zero, device: nil)
        let inputSink = RecordingInputEventSink()
        view.inputSink = inputSink
        let repeatedKeyDown = try #require(
            makeKeyEvent(type: .keyDown, isRepeat: true)
        )

        view.keyDown(with: repeatedKeyDown)

        #expect(inputSink.receivedEvents.isEmpty)
    }

    @MainActor
    private func makeKeyEvent(
        type: NSEvent.EventType,
        isRepeat: Bool
    ) -> NSEvent? {
        NSEvent.keyEvent(
            with: type,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "w",
            charactersIgnoringModifiers: "w",
            isARepeat: isRepeat,
            keyCode: 13
        )
    }
}
