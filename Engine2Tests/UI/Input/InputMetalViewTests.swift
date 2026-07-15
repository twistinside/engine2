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
        var receivedEvents: [InputEvent] = []
        view.inputHandler = { event in
            receivedEvents.append(event)
        }
        let keyDown = try #require(
            makeKeyEvent(type: .keyDown, isRepeat: false)
        )
        let keyUp = try #require(
            makeKeyEvent(type: .keyUp, isRepeat: false)
        )

        view.keyDown(with: keyDown)
        view.keyUp(with: keyUp)

        #expect(view.acceptsFirstResponder)
        #expect(receivedEvents.count == 2)

        guard case let .keyDown(downKey) = receivedEvents[0],
              case let .keyUp(upKey) = receivedEvents[1]
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
        var receivedEventCount = 0
        view.inputHandler = { (_: InputEvent) in
            receivedEventCount += 1
        }
        let repeatedKeyDown = try #require(
            makeKeyEvent(type: .keyDown, isRepeat: true)
        )

        view.keyDown(with: repeatedKeyDown)

        #expect(receivedEventCount == 0)
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
