//
//  InputStateTests.swift
//  Engine2Tests
//
//  Created by Codex on 6/14/26.
//

import simd
import Testing
@testable import Engine2

struct InputStateTests {
    @Test func mouseDragAndScrollAccumulateTransientInput() async throws {
        var input = InputState()

        input.apply(.mouseButtonDown(.left, position: SIMD2<Float>(10, 20)))
        input.apply(.mouseDragged(delta: SIMD2<Float>(3, -2), position: SIMD2<Float>(13, 18)))
        input.apply(.scroll(delta: SIMD2<Float>(0, -4)))

        #expect(input.mouse.buttons == [.left])
        #expect(input.mouse.position == SIMD2<Float>(13, 18))
        #expect(input.mouse.delta == SIMD2<Float>(3, -2))
        #expect(input.mouse.scrollDelta == SIMD2<Float>(0, -4))
    }

    @Test func keyDownAndUpUpdateHeldKeyboardState() async throws {
        var input = InputState()
        let key = KeyboardKey.make(keyCode: 13, charactersIgnoringModifiers: "w")

        input.apply(.keyDown(key))
        #expect(input.keyboard.keys == [key])

        input.apply(.keyUp(key))
        #expect(input.keyboard.keys.isEmpty)
    }

    @Test func mouseButtonUpRemovesHeldButtonAndUpdatesPointerPosition() {
        var input = InputState()

        input.apply(.mouseButtonDown(.right, position: SIMD2<Float>(2, 3)))
        input.apply(.mouseButtonUp(.right, position: SIMD2<Float>(8, 9)))

        #expect(input.mouse.buttons.isEmpty)
        #expect(input.mouse.position == SIMD2<Float>(8, 9))
    }

    @Test func historyTokensHaveStableOrderingAndRoundedDeltas() {
        var input = InputState()
        input.apply(.mouseButtonDown(.other(5), position: .zero))
        input.apply(.mouseButtonDown(.middle, position: .zero))
        input.apply(.mouseButtonDown(.right, position: .zero))
        input.apply(.mouseButtonDown(.left, position: .zero))
        input.apply(
            .mouseDragged(
                delta: SIMD2<Float>(1.6, -1.6),
                position: .zero
            )
        )
        input.apply(.scroll(delta: SIMD2<Float>(0, 0.4)))
        input.apply(
            .keyDown(
                KeyboardKey.make(
                    keyCode: 6,
                    charactersIgnoringModifiers: "z"
                )
            )
        )
        input.apply(
            .keyDown(
                KeyboardKey.make(
                    keyCode: 0,
                    charactersIgnoringModifiers: "a"
                )
            )
        )

        #expect(
            input.currentHistoryTokens() == [
                "LMB",
                "RMB",
                "MMB",
                "M5",
                "Mouse dx:+2 dy:-2",
                "Wheel:+0",
                "A",
                "Z"
            ]
        )
    }

    @Test func cleanupClearsDeltasAndActionsButPreservesHeldState() async throws {
        var input = InputState()
        let key = KeyboardKey.make(keyCode: 49, charactersIgnoringModifiers: " ")

        input.apply(.mouseButtonDown(.left, position: .zero))
        input.apply(.mouseDragged(delta: SIMD2<Float>(5, 0), position: SIMD2<Float>(5, 0)))
        input.apply(.scroll(delta: SIMD2<Float>(0, 2)))
        input.apply(.keyDown(key))
        input.actions.cameraOrbitDelta = SIMD2<Float>(1, 0)
        input.actions.cameraZoomDelta = 1

        input.clearTransientInput()

        #expect(input.mouse.buttons == [.left])
        #expect(input.keyboard.keys == [key])
        #expect(input.mouse.delta == .zero)
        #expect(input.mouse.scrollDelta == .zero)
        #expect(input.actions.cameraOrbitDelta == .zero)
        #expect(input.actions.cameraZoomDelta == 0)
    }
}
