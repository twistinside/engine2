//
//  ManualClockTests.swift
//  Engine2Tests
//
//  Created by Codex on 3/10/26.
//

import Testing
@testable import Engine2

struct ManualClockTests {
    @Test func manualClockReturnsOnlyTimeThatWasAdvanced() async throws {
        var clock = ManualClock()

        clock.advance(by: .milliseconds(250))
        #expect(clock.consumeDeltaTime() == .milliseconds(250))
        #expect(clock.consumeDeltaTime() == .zero)

        clock.advance(by: .milliseconds(500))
        #expect(clock.consumeDeltaTime() == .milliseconds(500))
    }

}
