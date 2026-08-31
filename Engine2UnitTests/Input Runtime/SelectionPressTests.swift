import Testing
@testable import Engine2

struct SelectionPressTests {
    @Test func acceptsUnitCoordinatesAndPositiveAspectRatio() throws {
        let selectionPress = try #require(
            SelectionPress(
                normalizedPosition: SIMD2<Float>(0, 1),
                aspectRatio: 16 / 9
            )
        )

        #expect(selectionPress.normalizedPosition == SIMD2<Float>(0, 1))
        #expect(selectionPress.aspectRatio == Float(16) / 9)
    }

    @Test func rejectsNonfiniteOutOfRangeAndDegenerateValues() {
        #expect(SelectionPress(normalizedPosition: SIMD2<Float>(.nan, 0), aspectRatio: 1) == nil)
        #expect(SelectionPress(normalizedPosition: SIMD2<Float>(-0.1, 0), aspectRatio: 1) == nil)
        #expect(SelectionPress(normalizedPosition: SIMD2<Float>(0, 1.1), aspectRatio: 1) == nil)
        #expect(SelectionPress(normalizedPosition: .zero, aspectRatio: 0) == nil)
        #expect(SelectionPress(normalizedPosition: .zero, aspectRatio: .infinity) == nil)
    }
}
