import Foundation
import simd
import Testing
@testable import Engine2

struct OffscreenRenderRequestTests {
    @Test func requestIdentitySupportsFreshRawAndCodableRoundTrips() throws {
        let parsedRawValue = UUID(
            uuidString: "00000000-0000-0000-0000-000000000100"
        )
        let rawValue = try #require(parsedRawValue)
        let fixed = OffscreenRenderRequestID(rawValue: rawValue)
        let firstFresh = OffscreenRenderRequestID()
        let secondFresh = OffscreenRenderRequestID()

        #expect(firstFresh != secondFresh)
        #expect(rawRoundTrip(fixed) == fixed)

        let data = try JSONEncoder().encode(fixed)
        #expect(
            try JSONDecoder().decode(
                OffscreenRenderRequestID.self,
                from: data
            ) == fixed
        )
    }

    @Test func preservesExactIdentitySnapshotViewpointAndSettings() throws {
        let requestUUID = UUID(
            uuidString: "00000000-0000-0000-0000-000000000101"
        )!
        let requestID = OffscreenRenderRequestID(rawValue: requestUUID)
        let cursor = cursor(tick: 12)
        let snapshotCamera = Camera(
            position: SIMD3<Float>(1, 2, 3),
            rotation: Transform.identityRotation,
            projection: .standardPerspective
        )
        let snapshot = SimulationPresentationSnapshot(
            cursor: cursor,
            camera: snapshotCamera,
            entityPresentations: []
        )
        let viewpoint = viewpoint(revision: 7)
        let renderSize = try RenderPixelSize(width: 640, height: 480)
        let exposure = ManualExposure(multiplier: 2)
        let settings = OffscreenRenderSettings(
            size: renderSize,
            outputMode: .viewSpaceNormals,
            exposure: exposure
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

    private func cursor(tick: UInt64) -> SimulationCursor {
        let sessionUUID = UUID(
            uuidString: "00000000-0000-0000-0000-000000000102"
        )!
        let sessionID = SimulationSessionID(rawValue: sessionUUID)
        let simulationTick = SimulationTick(rawValue: tick)
        return SimulationCursor(
            sessionID: sessionID,
            tick: simulationTick
        )
    }

    private func viewpoint(revision: UInt64) -> RenderViewpoint {
        let viewpointUUID = UUID(
            uuidString: "00000000-0000-0000-0000-000000000103"
        )!
        let viewpointID = RenderViewpointID(rawValue: viewpointUUID)
        let viewpointRevision = RenderViewpointRevision(rawValue: revision)
        let camera = Camera(
            position: SIMD3<Float>(4, 5, 6),
            rotation: Transform.identityRotation,
            projection: .standardPerspective
        )
        return RenderViewpoint(
            id: viewpointID,
            revision: viewpointRevision,
            camera: camera
        )
    }

    private func rawRoundTrip<Value>(_ value: Value) -> Value? where Value: Equatable & RawRepresentable {
        Value(rawValue: value.rawValue)
    }
}
