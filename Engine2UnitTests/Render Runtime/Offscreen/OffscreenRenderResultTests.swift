import Foundation
import simd
import Testing
@testable import Engine2

struct OffscreenRenderResultTests {
    @Test func echoesExactRequestAttributionAndDetachedImage() throws {
        let requestUUID = UUID(
            uuidString: "00000000-0000-0000-0000-000000000111"
        )!
        let requestID = OffscreenRenderRequestID(rawValue: requestUUID)
        let sessionUUID = UUID(
            uuidString: "00000000-0000-0000-0000-000000000112"
        )!
        let sessionID = SimulationSessionID(rawValue: sessionUUID)
        let tick = SimulationTick(rawValue: 19)
        let cursor = SimulationCursor(
            sessionID: sessionID,
            tick: tick
        )
        let viewpointUUID = UUID(
            uuidString: "00000000-0000-0000-0000-000000000113"
        )!
        let viewpointID = RenderViewpointID(rawValue: viewpointUUID)
        let viewpointRevision = RenderViewpointRevision(rawValue: 23)
        let cameraPosition = SIMD3<Float>(7, 8, 9)
        let camera = Camera(
            position: cameraPosition,
            rotation: Transform.identityRotation,
            projection: .standardPerspective
        )
        let viewpoint = RenderViewpoint(
            id: viewpointID,
            revision: viewpointRevision,
            camera: camera
        )
        let size = try RenderPixelSize(width: 2, height: 1)
        let exposure = ManualExposure(multiplier: 1.5)
        let settings = OffscreenRenderSettings(
            size: size,
            outputMode: .surface,
            exposure: exposure
        )
        let bytes = Data([0, 1, 2, 3, 4, 5, 6, 7])
        let image = try RenderedBGRA8SRGBImage(size: size, bytes: bytes)

        let result = OffscreenRenderResult(
            requestID: requestID,
            sourceCursor: cursor,
            viewpoint: viewpoint,
            settings: settings,
            image: image
        )

        #expect(result.requestID == requestID)
        #expect(result.sourceCursor == cursor)
        #expect(result.viewpoint == viewpoint)
        #expect(result.viewpoint.id == viewpoint.id)
        #expect(result.viewpoint.revision == viewpoint.revision)
        #expect(result.viewpoint.camera == viewpoint.camera)
        #expect(result.settings == settings)
        #expect(result.image == image)
    }
}
