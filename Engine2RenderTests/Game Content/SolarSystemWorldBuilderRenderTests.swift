import Testing
@testable import Engine2

struct SolarSystemWorldBuilderRenderTests {
    private static let imageDimension = 1_024
    private static let searchRadiusPixels = 5

    @Test func everyBodyProducesVisiblePixelsInTheAuthoredSystemView() async throws {
        let content = SolarSystemGameContent()
        let world = content.worldBuilder.buildWorld()
        let snapshot = world.presentationSnapshot(
            at: SimulationCursor(
                sessionID: SimulationSessionID(),
                tick: .zero
            )
        )
        let runtime = try MetalOffscreenRenderRuntime(
            catalog: content.renderAssetCatalog,
            limits: .conservative
        )
        let size = try RenderPixelSize(
            width: Self.imageDimension,
            height: Self.imageDimension
        )
        #expect(snapshot.entityPresentations.count == 9)
        for presentation in snapshot.entityPresentations {
            let isolatedSnapshot = SimulationPresentationSnapshot(
                cursor: snapshot.cursor,
                camera: snapshot.camera,
                entityPresentations: [presentation]
            )
            let request = OffscreenRenderRequest(
                id: OffscreenRenderRequestID(),
                presentationSnapshot: isolatedSnapshot,
                viewpoint: RenderViewpoint(
                    id: RenderViewpointID(),
                    revision: .zero,
                    camera: snapshot.camera
                ),
                settings: OffscreenRenderSettings(
                    size: size,
                    outputMode: .surface,
                    exposure: .validation
                )
            )
            let result = try completedResult(
                from: await runtime.render(request)
            )
            let pixels = [UInt8](result.image.bytes)
            let position = try #require(presentation.position)
            let center = try projectedPixelCenter(
                for: position,
                camera: snapshot.camera
            )
            #expect(
                containsVisiblePixel(
                    around: center,
                    bytesPerRow: result.image.bytesPerRow,
                    pixels: pixels
                ),
                "Entity \(presentation.id) must remain visible in the authored system view."
            )
        }
    }

    private func completedResult(
        from outcome: OffscreenRenderOutcome
    ) throws -> OffscreenRenderResult {
        guard case let .completed(result) = outcome else {
            Issue.record("Expected a completed Solar System render, received \(outcome).")
            throw UnexpectedOutcome()
        }
        return result
    }

    private func projectedPixelCenter(
        for position: SIMD3<Float>,
        camera: Camera
    ) throws -> SIMD2<Int> {
        let clipPosition = camera.viewProjectionMatrix(aspectRatio: 1) *
            SIMD4<Float>(position, 1)
        guard clipPosition.isFinite, clipPosition.w > 0 else {
            Issue.record("The Solar System body must project in front of the camera.")
            throw InvalidProjectedPosition()
        }
        let normalizedX = clipPosition.x / clipPosition.w
        let normalizedY = clipPosition.y / clipPosition.w
        let maximumPixel = Float(Self.imageDimension - 1)
        return SIMD2<Int>(
            Int(((normalizedX + 1) / 2 * maximumPixel).rounded()),
            Int(((1 - normalizedY) / 2 * maximumPixel).rounded())
        )
    }

    private func containsVisiblePixel(
        around center: SIMD2<Int>,
        bytesPerRow: Int,
        pixels: [UInt8]
    ) -> Bool {
        let minimumX = max(0, center.x - Self.searchRadiusPixels)
        let maximumX = min(
            Self.imageDimension - 1,
            center.x + Self.searchRadiusPixels
        )
        let minimumY = max(0, center.y - Self.searchRadiusPixels)
        let maximumY = min(
            Self.imageDimension - 1,
            center.y + Self.searchRadiusPixels
        )

        for y in minimumY...maximumY {
            for x in minimumX...maximumX {
                let offset = y * bytesPerRow + x * 4
                if pixels[offset] != 0 ||
                    pixels[offset + 1] != 0 ||
                    pixels[offset + 2] != 0 {
                    return true
                }
            }
        }
        return false
    }

    private struct InvalidProjectedPosition: Error {}
    private struct UnexpectedOutcome: Error {}
}
