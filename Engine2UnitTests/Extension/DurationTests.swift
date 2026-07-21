import Testing
@testable import Engine2

struct DurationTests {
    @Test func secondsIncludesWholeAndFractionalComponents() {
        #expect(Duration.milliseconds(1_500).seconds.isApproximately(1.5))
        #expect(Duration.microseconds(125_000).seconds.isApproximately(0.125))
        #expect(Duration.milliseconds(-250).seconds.isApproximately(-0.25))
    }

    @Test func diagnosticsNanosecondsNamesUnitsAndClampsInvalidRanges() {
        #expect(Duration.milliseconds(125).diagnosticsNanoseconds == 125_000_000)
        #expect(Duration.nanoseconds(-1).diagnosticsNanoseconds == 0)
        #expect(Duration.seconds(Int64.max).diagnosticsNanoseconds == UInt64.max)
    }
}

private extension Float {
    func isApproximately(_ other: Float, tolerance: Float = 0.000_001) -> Bool {
        abs(self - other) <= tolerance
    }
}
