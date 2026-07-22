import Testing
@testable import Engine2

struct AppDebugOptionsTests {
    @Test func inputHistoryIsVisibleByDefault() {
        #expect(AppDebugOptions().showsInputHistory)
    }

    @Test func surfaceRenderingIsTheDefaultOutput() {
        #expect(AppDebugOptions().renderOutputMode == .surface)
    }

    @Test func diagnosticsHUDIsOptIn() {
        #expect(!AppDebugOptions().showsDiagnosticsHUD)
    }
}
