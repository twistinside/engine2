import Testing
@testable import Engine2

struct DurationTests {
    @Test func secondsPreserveWholeAndFractionalComponents() {
        #expect(Duration.milliseconds(1_500).seconds == 1.5)
        #expect(Duration.microseconds(125_000).seconds == 0.125)
        #expect(Duration.milliseconds(-250).seconds == -0.25)
    }

    @Test func millisecondsPreserveDiagnosticPrecision() {
        #expect(abs(Duration.microseconds(1_234).milliseconds - 1.234) < 0.000_000_001)
        #expect(abs(Duration.nanoseconds(-250).milliseconds + 0.000_25) < 0.000_000_001)
    }
}
