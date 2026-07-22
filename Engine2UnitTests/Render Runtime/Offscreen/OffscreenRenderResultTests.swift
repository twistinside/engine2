import Foundation
import simd
import Testing
@testable import Engine2

struct OffscreenRenderResultTests {
    @Test func echoesExactRequestAttributionAndDetachedImage() throws {
        let requestID = OffscreenRenderRequestID(
            rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
        )
        let cursor = SimulationCursor(
            sessionID: SimulationSessionID(
                rawValue: UUID(
                    uuidString: "00000000-0000-0000-0000-000000000112"
                )!
            ),
            tick: SimulationTick(rawValue: 19)
        )
        let viewpoint = RenderViewpoint(
            id: RenderViewpointID(
                rawValue: UUID(
                    uuidString: "00000000-0000-0000-0000-000000000113"
                )!
            ),
            revision: RenderViewpointRevision(rawValue: 23),
            camera: Camera(position: SIMD3<Float>(7, 8, 9))
        )
        let size = try RenderPixelSize(width: 2, height: 1)
        let settings = OffscreenRenderSettings(
            size: size,
            outputMode: .surface,
            exposure: ManualExposure(multiplier: 1.5)
        )
        let image = try RenderedBGRA8SRGBImage(
            size: size,
            bytes: Data([0, 1, 2, 3, 4, 5, 6, 7])
        )

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
