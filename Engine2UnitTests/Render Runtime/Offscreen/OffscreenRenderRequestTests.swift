import Foundation
import simd
import Testing
@testable import Engine2

struct OffscreenRenderRequestTests {
    @Test func requestIdentitySupportsFreshRawAndCodableRoundTrips() throws {
        let rawValue = try #require(
            UUID(uuidString: "00000000-0000-0000-0000-000000000100")
        )
        let fixed = OffscreenRenderRequestID(rawValue: rawValue)
        let firstFresh = OffscreenRenderRequestID()
        let secondFresh = OffscreenRenderRequestID()

        #expect(firstFresh != secondFresh)
        #expect(Self.rawRoundTrip(fixed) == fixed)

        let data = try JSONEncoder().encode(fixed)
        #expect(
            try JSONDecoder().decode(
                OffscreenRenderRequestID.self,
                from: data
            ) == fixed
        )
    }

    @Test func preservesExactIdentitySnapshotViewpointAndSettings() throws {
        let requestID = OffscreenRenderRequestID(
            rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
        )
        let cursor = Self.cursor(tick: 12)
        let snapshot = SimulationPresentationSnapshot(
            cursor: cursor,
            camera: Camera(position: SIMD3<Float>(1, 2, 3)),
            entityPresentations: []
        )
        let viewpoint = Self.viewpoint(revision: 7)
        let settings = OffscreenRenderSettings(
            size: try RenderPixelSize(width: 640, height: 480),
            outputMode: .viewSpaceNormals,
            exposure: ManualExposure(multiplier: 2)
        )

        let request = OffscreenRenderRequest(
            id: requestID,
            presentationSnapshot: snapshot,
            viewpoint: viewpoint,
            settings: settings
        )

        #expect(request.id == requestID)
        #expect(request.presentationSnapshot == snapshot)
        #expect(request.presentationSnapshot.cursor == cursor)
        #expect(request.viewpoint == viewpoint)
        #expect(request.settings == settings)
    }

    private static func cursor(tick: UInt64) -> SimulationCursor {
        SimulationCursor(
            sessionID: SimulationSessionID(
                rawValue: UUID(
                    uuidString: "00000000-0000-0000-0000-000000000102"
                )!
            ),
            tick: SimulationTick(rawValue: tick)
        )
    }

    private static func viewpoint(revision: UInt64) -> RenderViewpoint {
        RenderViewpoint(
            id: RenderViewpointID(
                rawValue: UUID(
                    uuidString: "00000000-0000-0000-0000-000000000103"
                )!
            ),
            revision: RenderViewpointRevision(rawValue: revision),
            camera: Camera(position: SIMD3<Float>(4, 5, 6))
        )
    }

    private static func rawRoundTrip<Value>(
        _ value: Value
    ) -> Value? where Value: Equatable & RawRepresentable {
        Value(rawValue: value.rawValue)
    }
}
