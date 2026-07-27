import Testing
@testable import Engine2

struct AppDebugOptionsTests {
    @Test func inputHistoryIsHiddenByDefault() {
        #expect(AppDebugOptions().showsInputHistory == false)
    }

    @Test func surfaceRenderingIsTheDefaultOutput() {
        #expect(AppDebugOptions().renderOutputMode == .surface)
    }
}
