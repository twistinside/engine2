import Testing
@testable import Engine2

struct InputEventTests {
    @Test func diagnosticsIdentityIgnoresPayloadButCoversEveryEventCase() {
        let events: [InputEvent] = [
            .mouseButtonDown(.left, position: SIMD2<Float>(1, 2)),
            .mouseButtonUp(.other(4), position: SIMD2<Float>(3, 4)),
            .mouseDragged(delta: SIMD2<Float>(5, 6), position: SIMD2<Float>(7, 8)),
            .scroll(delta: SIMD2<Float>(9, 10)),
            .keyDown(KeyboardKey(keyCode: 1, displayName: "A")),
            .keyUp(KeyboardKey(keyCode: 2, displayName: "B"))
        ]

        #expect(events.map(\.diagnosticsID) == [
            .mouseButtonDown,
            .mouseButtonUp,
            .mouseDragged,
            .scroll,
            .keyDown,
            .keyUp
        ])
    }

    @Test func onlyHighCadenceContinuousEventsUseSampling() {
        let discreteEvents: [InputEvent] = [
            .mouseButtonDown(.left, position: .zero),
            .mouseButtonUp(.left, position: .zero),
            .keyDown(KeyboardKey(keyCode: 1, displayName: "A")),
            .keyUp(KeyboardKey(keyCode: 1, displayName: "A"))
        ]
        let continuousEvents: [InputEvent] = [
            .mouseDragged(delta: .zero, position: .zero),
            .scroll(delta: .zero)
        ]

        #expect(discreteEvents.allSatisfy { !$0.usesContinuousDiagnosticsSampling })
        #expect(continuousEvents.allSatisfy { $0.usesContinuousDiagnosticsSampling })
    }
}
