import Testing
@testable import Engine2
@testable import Engine2RealtimeAssembly

struct AppDebugOptionsTests {
    @Test func inputHistoryIsHiddenByDefault() {
        #expect(AppDebugOptions().showsInputHistory == false)
    }

    @Test func surfaceRenderingIsTheDefaultOutput() {
        #expect(AppDebugOptions().renderOutputMode == .surface)
    }
}
