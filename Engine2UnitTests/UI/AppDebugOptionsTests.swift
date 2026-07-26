import Testing
@testable import Engine2

struct AppDebugOptionsTests {
    @Test func inputHistoryIsHiddenByDefault() {
        let options = AppDebugOptions()
        #expect(options.showsInputHistory == false)
    }

    @Test func surfaceRenderingIsTheDefaultOutput() {
        let options = AppDebugOptions()
        #expect(options.renderOutputMode == .surface)
    }
}
