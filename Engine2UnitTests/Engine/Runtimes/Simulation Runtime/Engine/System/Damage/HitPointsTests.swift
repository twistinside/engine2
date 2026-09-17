import Foundation
import Testing
@testable import Engine2

struct HitPointsTests {
    @Test(arguments: [0, Double.leastNonzeroMagnitude, 1, Double.greatestFiniteMagnitude])
    func finiteNonnegativeAmountsRoundTripThroughJSON(rawValue: Double) throws {
        let original = HitPoints(rawValue: rawValue)
        let encoded = try JSONEncoder().encode(original)

        let decoded = try JSONDecoder().decode(HitPoints.self, from: encoded)

        #expect(decoded == original)
    }

    @Test(arguments: ["-1", "\"NaN\"", "\"Infinity\"", "\"-Infinity\""])
    func decodingRejectsNegativeAndNonfiniteAmounts(jsonValue: String) {
        let data = Data("{\"rawValue\":\(jsonValue)}".utf8)
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: "Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )

        #expect(throws: DecodingError.self) {
            try decoder.decode(HitPoints.self, from: data)
        }
    }
}
