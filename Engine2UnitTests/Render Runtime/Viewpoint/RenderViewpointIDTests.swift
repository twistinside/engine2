import Foundation
import Testing
@testable import Engine2

struct RenderViewpointIDTests {
    @Test func createsFreshIdentitiesAndRestoresRawValues() throws {
        let first = RenderViewpointID()
        let second = RenderViewpointID()

        #expect(first != second)
        let restored = RenderViewpointID(rawValue: first.rawValue)
        #expect(restored == first)
        #expect(rawRoundTrip(first) == first)

        let data = try JSONEncoder().encode(first)
        #expect(try JSONDecoder().decode(RenderViewpointID.self, from: data) == first)
    }

    private func rawRoundTrip<Value>(_ value: Value) -> Value? where Value: Equatable & RawRepresentable {
        Value(rawValue: value.rawValue)
    }
}
