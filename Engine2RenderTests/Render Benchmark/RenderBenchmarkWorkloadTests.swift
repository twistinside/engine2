import Metal
import Testing
@testable import Engine2

struct RenderBenchmarkWorkloadTests {
    @Test func validatesStrictOrderingAndOnePixelSize() throws {
        let fixture = try RenderBenchmarkTestFixture()
        let frames = [
            fixture.frame(sequence: 10, tick: 0),
            fixture.frame(sequence: 20, tick: 1)
        ]

        let workload = try RenderBenchmarkWorkload(frames: frames)

        #expect(workload.frames.map(\.sequence) == [10, 20])
        #expect(workload.pixelSize == fixture.pixelSize)
    }

    @Test func rejectsEmptyAndNonincreasingWorkloads() throws {
        #expect(throws: RenderBenchmarkError.emptyWorkload) {
            try RenderBenchmarkWorkload(frames: [])
        }

        let fixture = try RenderBenchmarkTestFixture()
        #expect(
            throws: RenderBenchmarkError.nonincreasingSequence(
                previous: 7,
                current: 7
            )
        ) {
            try RenderBenchmarkWorkload(
                frames: [
                    fixture.frame(sequence: 7, tick: 0),
                    fixture.frame(sequence: 7, tick: 1)
                ]
            )
        }
    }

    @Test func rejectsHeterogeneousSizesAndNonfiniteClearColor() throws {
        let fixture = try RenderBenchmarkTestFixture()
        let otherSize = try RenderPixelSize(width: 32, height: 24)
        #expect(
            throws: RenderBenchmarkError.heterogeneousPixelSize(
                expected: fixture.pixelSize,
                actual: otherSize,
                sequence: 1
            )
        ) {
            try RenderBenchmarkWorkload(
                frames: [
                    fixture.frame(sequence: 0, tick: 0),
                    fixture.frame(
                        sequence: 1,
                        tick: 1,
                        size: otherSize
                    )
                ]
            )
        }

        #expect(
            throws: RenderBenchmarkError.nonfiniteClearColor(sequence: 0)
        ) {
            try RenderBenchmarkWorkload(
                frames: [
                    fixture.frame(
                        sequence: 0,
                        tick: 0,
                        clearColor: MTLClearColor(
                            red: .nan,
                            green: 0,
                            blue: 0,
                            alpha: 1
                        )
                    )
                ]
            )
        }
    }
}
