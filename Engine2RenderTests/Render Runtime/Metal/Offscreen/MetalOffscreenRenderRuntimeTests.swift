import simd
import Testing
@testable import Engine2

struct MetalOffscreenRenderRuntimeTests {
    @MainActor
    @Test func rendersExactMaterialSceneIntoDetachedOpaquePixels() async throws {
        let fixture = makeFixture()
        let runtime = try MetalOffscreenRenderRuntime(
            catalog: fixture.content.renderAssetCatalog
        )
        let size = try RenderPixelSize(width: 320, height: 240)
        let settings = OffscreenRenderSettings(
            size: size,
            outputMode: .surface,
            exposure: .validation
        )
        let request = OffscreenRenderRequest(
            presentationSnapshot: fixture.snapshot,
            viewpoint: fixture.viewpoint,
            settings: settings
        )

        let result = try completedResult(from: await runtime.render(request))

        #expect(result.requestID == request.id)
        #expect(result.sourceCursor == fixture.snapshot.cursor)
        #expect(result.viewpoint == fixture.viewpoint)
        #expect(result.settings == settings)
        #expect(result.image.size == size)
        #expect(result.image.bytesPerRow == 320 * 4)
        #expect(result.image.bytes.count == 320 * 240 * 4)
        #expect(result.image.origin == .topLeft)

        let pixels = [UInt8](result.image.bytes)
        let pixelOffsets = stride(from: 0, to: pixels.count, by: 4)
        #expect(pixelOffsets.allSatisfy { pixels[$0 + 3] == 255 })
        #expect(pixelOffsets.contains { offset in
            pixels[offset] != 0
                || pixels[offset + 1] != 0
                || pixels[offset + 2] != 0
        })
    }

    @MainActor
    @Test func overLimitRejectionDoesNotPoisonFollowingRequest() async throws {
        let fixture = makeFixture()
        let limits = OffscreenRenderLimits(
            maxDimension: 128,
            maxPixelCount: 128 * 128
        )
        let runtime = try MetalOffscreenRenderRuntime(
            catalog: fixture.content.renderAssetCatalog,
            limits: limits
        )
        let excessiveSize = try RenderPixelSize(width: 320, height: 240)
        let excessiveRequest = OffscreenRenderRequest(
            presentationSnapshot: fixture.snapshot,
            viewpoint: fixture.viewpoint,
            settings: OffscreenRenderSettings(size: excessiveSize)
        )

        let rejected = await runtime.render(excessiveRequest)

        #expect(
            rejected == .rejected(
                .exceedsLimits(requested: excessiveSize, limits: limits)
            )
        )

        let acceptedRequest = OffscreenRenderRequest(
            presentationSnapshot: fixture.snapshot,
            viewpoint: fixture.viewpoint,
            settings: OffscreenRenderSettings(
                size: try RenderPixelSize(width: 96, height: 64)
            )
        )
        let result = try completedResult(
            from: await runtime.render(acceptedRequest)
        )

        #expect(result.requestID == acceptedRequest.id)
        #expect(result.sourceCursor == fixture.snapshot.cursor)
    }

    @MainActor
    @Test func invalidExplicitCameraIsRejectedBeforeSubmission() async throws {
        let fixture = makeFixture()
        let runtime = try MetalOffscreenRenderRuntime(
            catalog: fixture.content.renderAssetCatalog
        )
        let invalidViewpoint = RenderViewpoint(
            id: RenderViewpointID(),
            revision: .zero,
            camera: Camera(position: SIMD3<Float>(.nan, 0, 8))
        )
        let request = OffscreenRenderRequest(
            presentationSnapshot: fixture.snapshot,
            viewpoint: invalidViewpoint,
            settings: OffscreenRenderSettings(
                size: try RenderPixelSize(width: 96, height: 64)
            )
        )

        let outcome = await runtime.render(request)

        #expect(outcome == .rejected(.invalidViewpoint))
    }

    @MainActor
    @Test func projectionOverflowIdentifiesTheExactEntityBeforeSubmission() async throws {
        let fixture = makeFixture()
        let seed = try #require(fixture.snapshot.entityPresentations.first)
        let entityID = EntityID(index: 900, generation: 2)
        let snapshot = SimulationPresentationSnapshot(
            cursor: fixture.snapshot.cursor,
            camera: fixture.snapshot.camera,
            entityPresentations: [
                EntityPresentationSnapshot(
                    id: entityID,
                    position: SIMD3<Float>(.greatestFiniteMagnitude, 0, 0),
                    rotation: seed.rotation,
                    scale: seed.scale,
                    meshID: seed.meshID,
                    materialID: seed.materialID
                )
            ]
        )
        let runtime = try MetalOffscreenRenderRuntime(
            catalog: fixture.content.renderAssetCatalog
        )
        let request = OffscreenRenderRequest(
            presentationSnapshot: snapshot,
            viewpoint: fixture.viewpoint,
            settings: OffscreenRenderSettings(
                size: try RenderPixelSize(width: 96, height: 64)
            )
        )

        let outcome = await runtime.render(request)

        #expect(
            outcome == .rejected(
                .invalidPresentation(
                    .nonfiniteModelViewProjectionTransform(
                        entityID: entityID
                    )
                )
            )
        )
    }

    @MainActor
    @Test func excessiveProjectedSceneIsRejectedRatherThanTruncated() async throws {
        let fixture = makeFixture()
        let seed = try #require(fixture.snapshot.entityPresentations.first)
        let excessiveCount = FrameResources.maximumInstanceCount + 1
        let presentations = (0..<excessiveCount).map { index in
            EntityPresentationSnapshot(
                id: EntityID(index: index, generation: 0),
                position: seed.position,
                rotation: seed.rotation,
                scale: seed.scale,
                meshID: seed.meshID,
                materialID: seed.materialID
            )
        }
        let excessiveSnapshot = SimulationPresentationSnapshot(
            cursor: fixture.snapshot.cursor,
            camera: fixture.snapshot.camera,
            entityPresentations: presentations
        )
        let runtime = try MetalOffscreenRenderRuntime(
            catalog: fixture.content.renderAssetCatalog
        )
        let request = OffscreenRenderRequest(
            presentationSnapshot: excessiveSnapshot,
            viewpoint: fixture.viewpoint,
            settings: OffscreenRenderSettings(
                size: try RenderPixelSize(width: 96, height: 64)
            )
        )

        let outcome = await runtime.render(request)

        #expect(
            outcome == .rejected(
                .instanceLimitExceeded(
                    requested: excessiveCount,
                    maximum: FrameResources.maximumInstanceCount
                )
            )
        )
    }

    @MainActor
    @Test func sequentialViewpointRevisionsPreserveExactSourceCursor() async throws {
        let fixture = makeFixture()
        let runtime = try MetalOffscreenRenderRuntime(
            catalog: fixture.content.renderAssetCatalog
        )
        let viewpointID = RenderViewpointID()
        let firstViewpoint = RenderViewpoint(
            id: viewpointID,
            revision: .zero,
            camera: fixture.snapshot.camera
        )
        let secondViewpoint = RenderViewpoint(
            id: viewpointID,
            revision: RenderViewpointRevision.zero.advanced(),
            camera: Camera.lookingAt(
                .zero,
                from: SIMD3<Float>(1, 0, 8),
                projection: fixture.snapshot.camera.projection
            )
        )
        let settings = OffscreenRenderSettings(
            size: try RenderPixelSize(width: 160, height: 120)
        )
        let firstRequest = OffscreenRenderRequest(
            presentationSnapshot: fixture.snapshot,
            viewpoint: firstViewpoint,
            settings: settings
        )
        let secondRequest = OffscreenRenderRequest(
            presentationSnapshot: fixture.snapshot,
            viewpoint: secondViewpoint,
            settings: settings
        )

        let firstResult = try completedResult(
            from: await runtime.render(firstRequest)
        )
        let secondResult = try completedResult(
            from: await runtime.render(secondRequest)
        )

        #expect(firstResult.requestID == firstRequest.id)
        #expect(secondResult.requestID == secondRequest.id)
        #expect(firstResult.sourceCursor == fixture.snapshot.cursor)
        #expect(secondResult.sourceCursor == fixture.snapshot.cursor)
        #expect(firstResult.sourceCursor == secondResult.sourceCursor)
        #expect(firstResult.viewpoint == firstViewpoint)
        #expect(secondResult.viewpoint == secondViewpoint)
        #expect(firstResult.viewpoint.id == secondResult.viewpoint.id)
        #expect(firstResult.viewpoint.revision != secondResult.viewpoint.revision)
        #expect(firstResult.viewpoint.camera != secondResult.viewpoint.camera)
    }

    @MainActor
    @Test func missingModelFailsExactPreflightWithoutAffectingValidRuntime() async throws {
        let fixture = makeFixture()
        let request = OffscreenRenderRequest(
            presentationSnapshot: fixture.snapshot,
            viewpoint: fixture.viewpoint,
            settings: OffscreenRenderSettings(
                size: try RenderPixelSize(width: 96, height: 64)
            )
        )
        let incompleteRuntime = try MetalOffscreenRenderRuntime(
            catalog: .materialOnlyTestCatalog
        )

        let incompleteOutcome = await incompleteRuntime.render(request)

        guard case let .failed(failure) = incompleteOutcome else {
            Issue.record(
                "Expected exact preflight failure, received \(incompleteOutcome)"
            )
            throw UnexpectedOutcome()
        }
        #expect(failure.stage == .preparation)
        #expect(failure.backendDescription.contains("missingModel"))

        let validRuntime = try MetalOffscreenRenderRuntime(
            catalog: fixture.content.renderAssetCatalog
        )
        let result = try completedResult(
            from: await validRuntime.render(request)
        )

        #expect(result.requestID == request.id)
        #expect(result.sourceCursor == fixture.snapshot.cursor)
    }

    @MainActor
    private func makeFixture() -> (
        content: BasicGameContent,
        snapshot: SimulationPresentationSnapshot,
        viewpoint: RenderViewpoint
    ) {
        let content = BasicGameContent()
        let world = content.worldBuilder.buildWorld()
        let snapshot = world.presentationSnapshot(
            at: SimulationCursor(
                sessionID: SimulationSessionID(),
                tick: SimulationTick(rawValue: 7)
            )
        )
        let viewpoint = RenderViewpoint(
            id: RenderViewpointID(),
            revision: RenderViewpointRevision(rawValue: 11),
            camera: snapshot.camera
        )
        return (content, snapshot, viewpoint)
    }

    private func completedResult(
        from outcome: OffscreenRenderOutcome
    ) throws -> OffscreenRenderResult {
        guard case let .completed(result) = outcome else {
            Issue.record("Expected completed offscreen render, received \(outcome)")
            throw UnexpectedOutcome()
        }
        return result
    }

    private struct UnexpectedOutcome: Error {}
}
