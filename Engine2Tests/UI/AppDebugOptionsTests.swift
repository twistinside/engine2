import Testing
@testable import Engine2

struct AppDebugOptionsTests {
    @Test func inputHistoryIsVisibleByDefault() {
        #expect(AppDebugOptions().showsInputHistory)
    }
}
