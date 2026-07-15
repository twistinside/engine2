//
//  InputHistoryTests.swift
//  Engine2Tests
//
//  Created by Codex on 6/14/26.
//

import simd
import Testing
@testable import Engine2

struct InputHistoryTests {
    @Test func emptyFrameDoesNotAddHistoryRow() async throws {
        var input = InputState()

        input.recordHistoryFrame()

        #expect(input.history.isEmpty)
    }

    @Test func changedInputAddsNewestRowFirst() async throws {
        var input = InputState()
        let key = KeyboardKey.make(keyCode: 13, charactersIgnoringModifiers: "w")

        input.apply(.keyDown(key))
        input.recordHistoryFrame()
        input.apply(.mouseButtonDown(.left, position: .zero))
        input.recordHistoryFrame()

        #expect(input.history.count == 2)
        #expect(input.history[0].tokens == ["LMB", "W"])
        #expect(input.history[1].tokens == ["W"])
    }

    @Test func identicalHeldInputIncrementsDuration() async throws {
        var input = InputState()
        input.apply(.mouseButtonDown(.left, position: .zero))

        input.recordHistoryFrame()
        input.recordHistoryFrame()

        #expect(input.history.count == 1)
        #expect(input.history[0].tokens == ["LMB"])
        #expect(input.history[0].frameCount == 2)
    }

    @Test func historyRespectsLimit() async throws {
        var input = InputState()
        input.historyLimit = 3

        for index in 0..<5 {
            input.apply(.mouseDragged(delta: SIMD2<Float>(Float(index + 1), 0), position: .zero))
            input.recordHistoryFrame()
            input.clearTransientInput()
        }

        #expect(input.history.count == 3)
        #expect(input.history[0].tokens == ["Mouse dx:+5 dy:+0"])
        #expect(input.history[2].tokens == ["Mouse dx:+3 dy:+0"])
    }

    @Test func zeroHistoryLimitRetainsNoRows() {
        var input = InputState()
        input.historyLimit = 0
        input.apply(.mouseButtonDown(.left, position: .zero))

        input.recordHistoryFrame()

        #expect(input.history.isEmpty)
    }
}
