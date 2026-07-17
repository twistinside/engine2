import Foundation
import Testing
@testable import Engine2

struct SystemClockTests {
    @Test func systemClockUsesInjectedTimeSource() async throws {
        let baseInstant = SuspendingClock().now
        let samples = [
            baseInstant,
            baseInstant.advanced(by: .milliseconds(250)),
            baseInstant.advanced(by: .milliseconds(750)),
            baseInstant.advanced(by: .milliseconds(500))
        ]

        var sampleIndex = 0
        var clock = SystemClock(timeSource: {
            defer { sampleIndex += 1 }
            return samples[sampleIndex]
        })

        #expect(clock.consumeDeltaTime() == .milliseconds(250))
        #expect(clock.consumeDeltaTime() == .milliseconds(500))

        // Clamp backward jumps from an injected source instead of stepping the engine backwards.
        #expect(clock.consumeDeltaTime() == .zero)
    }
}
