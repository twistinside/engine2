import Testing
@testable import Engine2

struct AppDebugOptionsTests {
    @Test func surfaceRenderingIsTheDefaultOutput() {
        #expect(AppDebugOptions().renderOutputMode == .surface)
    }
}
