import Foundation
import Testing
@testable import Engine2

struct RenderViewpointIDTests {
    @Test func createsFreshIdentitiesAndRestoresRawValues() throws {
        let first = RenderViewpointID()
        let second = RenderViewpointID()

        #expect(first != second)
        #expect(RenderViewpointID(rawValue: first.rawValue) == first)

        let data = try JSONEncoder().encode(first)
        #expect(try JSONDecoder().decode(RenderViewpointID.self, from: data) == first)
    }
}
