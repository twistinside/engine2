import Testing
@testable import Engine2

struct RenderViewpointRevisionTests {
    @Test func zeroAdvancesMonotonically() {
        let first = RenderViewpointRevision.zero
        let second = first.advanced()

        #expect(first.rawValue == 0)
        #expect(second.rawValue == 1)
        #expect(first < second)
    }
}
