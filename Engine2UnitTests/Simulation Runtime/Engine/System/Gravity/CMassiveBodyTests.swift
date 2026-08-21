import Foundation
import Testing
@testable import Engine2

struct CMassiveBodyTests {
    @Test func codableRoundTripPreservesValidatedPhysicalFacts() throws {
        let massiveBody = CMassiveBody(
            mass: .earth,
            physicalRadius: .earthRadius
        )

        let data = try JSONEncoder().encode(massiveBody)
        let decoded = try JSONDecoder().decode(
            CMassiveBody.self,
            from: data
        )

        #expect(decoded == massiveBody)
    }

    @Test func decodingRejectsValuesThatBypassQuantityInitializers() {
        expectDecodeFailure(
            """
            {
              "mass": {"kilograms": 0},
              "physicalRadius": {"meters": 1}
            }
            """
        )
        expectDecodeFailure(
            """
            {
              "mass": {"kilograms": 1},
              "physicalRadius": {"meters": 0}
            }
            """
        )
        expectDecodeFailure(
            """
            {
              "mass": {"kilograms": "Infinity"},
              "physicalRadius": {"meters": 1}
            }
            """
        )
        expectDecodeFailure(
            """
            {
              "mass": {"kilograms": 1},
              "physicalRadius": {"meters": "NaN"}
            }
            """
        )
    }

    private func expectDecodeFailure(_ json: String) {
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: "Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )

        #expect(throws: DecodingError.self) {
            try decoder.decode(
                CMassiveBody.self,
                from: Data(json.utf8)
            )
        }
    }
}
