import CoreGraphics
import Foundation
import ImageIO
import simd
import Testing
import UniformTypeIdentifiers
@testable import Engine2

struct OfflineCaptureConfigurationTests {
    @MainActor
    @Test
    func composesExactSimulationMetalAndJPEGWorkAcrossSequentialCaptures() async throws {
        let sessionID = SimulationSessionID(
            rawValue: UUID(
                uuidString: "40000000-0000-0000-0000-000000000001"
            )!
        )
        let assembly = try OfflineCaptureConfiguration().makeAssembly(
            gameContent: BasicGameContent(),
            sessionID: sessionID
        )
        let captureTarget = assembly.captureTarget

        let viewpointID = RenderViewpointID(
            rawValue: UUID(
                uuidString: "40000000-0000-0000-0000-000000000002"
            )!
        )
        let firstViewpoint = RenderViewpoint(
            id: viewpointID,
            revision: RenderViewpointRevision(rawValue: 7),
            camera: Camera.lookingAt(
                .zero,
                from: SIMD3<Float>(0, 0, 8)
            )
        )
        let firstRenderSettings = OffscreenRenderSettings(
            size: try RenderPixelSize(width: 96, height: 64),
            outputMode: .surface,
            exposure: .validation
        )
        let firstJPEGSettings = JPEGEncodingSettings(
            quality: try JPEGQuality(0.72)
        )
        let firstRequest = OfflineCaptureRequest(
            advanceRequest: SimulationAdvanceRequest(
                expectedCursor: assembly.initialCursor,
                stepCount: .one
            ),
            renderRequestID: OffscreenRenderRequestID(
                rawValue: UUID(
                    uuidString: "40000000-0000-0000-0000-000000000003"
                )!
            ),
            viewpoint: firstViewpoint,
            renderSettings: firstRenderSettings,
            jpegSettings: firstJPEGSettings
        )

        // The public assembly boundary performs real fixed-step Simulation,
        // real Metal offscreen submission/readback, then real Image I/O JPEG
        // derivation without exposing any of its concrete Runtime references.
        let firstResult = try completedResult(
            from: await captureTarget.capture(firstRequest)
        )

        #expect(
            firstResult.advanceResult.initialCursor == assembly.initialCursor
        )
        #expect(firstResult.advanceResult.initialCursor.sessionID == sessionID)
        #expect(firstResult.advanceResult.initialCursor.tick == .zero)
        #expect(
            firstResult.advanceResult.finalCursor
                == assembly.initialCursor.advanced()
        )
        #expect(firstResult.advanceResult.completedStepCount.rawValue == 1)
        #expect(
            firstResult.advanceResult.finalPresentationSnapshot.cursor
                == firstResult.advanceResult.finalCursor
        )
        try assertArtifact(
            firstResult.artifact,
            requestID: firstRequest.renderRequestID,
            cursor: firstResult.advanceResult.finalCursor,
            viewpoint: firstViewpoint,
            renderSettings: firstRenderSettings,
            jpegSettings: firstJPEGSettings
        )

        let secondViewpoint = RenderViewpoint(
            id: viewpointID,
            revision: firstViewpoint.revision.advanced(),
            camera: Camera.lookingAt(
                .zero,
                from: SIMD3<Float>(1, 0.5, 8)
            )
        )
        let secondRenderSettings = OffscreenRenderSettings(
            size: try RenderPixelSize(width: 80, height: 60),
            outputMode: .viewSpaceNormals,
            exposure: ManualExposure(multiplier: 1.25)
        )
        let secondJPEGSettings = JPEGEncodingSettings(quality: .maximum)
        let secondRequest = OfflineCaptureRequest(
            advanceRequest: SimulationAdvanceRequest(
                expectedCursor: firstResult.advanceResult.finalCursor,
                stepCount: SimulationStepCount(rawValue: 2)
            ),
            renderRequestID: OffscreenRenderRequestID(
                rawValue: UUID(
                    uuidString: "40000000-0000-0000-0000-000000000004"
                )!
            ),
            viewpoint: secondViewpoint,
            renderSettings: secondRenderSettings,
            jpegSettings: secondJPEGSettings
        )

        let secondResult = try completedResult(
            from: await captureTarget.capture(secondRequest)
        )

        // The first outcome is the only cursor authority needed to issue the
        // next request. No hidden Runtime read or latest-value sample is used.
        #expect(
            secondResult.advanceResult.initialCursor
                == firstResult.advanceResult.finalCursor
        )
        #expect(
            secondResult.advanceResult.initialCursor.tick
                == SimulationTick(rawValue: 1)
        )
        #expect(
            secondResult.advanceResult.finalCursor.tick
                == SimulationTick(rawValue: 3)
        )
        #expect(secondResult.advanceResult.finalCursor.sessionID == sessionID)
        #expect(secondResult.advanceResult.completedStepCount.rawValue == 2)
        #expect(
            secondResult.advanceResult.finalPresentationSnapshot.cursor
                == secondResult.advanceResult.finalCursor
        )
        try assertArtifact(
            secondResult.artifact,
            requestID: secondRequest.renderRequestID,
            cursor: secondResult.advanceResult.finalCursor,
            viewpoint: secondViewpoint,
            renderSettings: secondRenderSettings,
            jpegSettings: secondJPEGSettings
        )

        #expect(
            secondResult.artifact.sourceRequestID
                != firstResult.artifact.sourceRequestID
        )
        #expect(
            secondResult.artifact.sourceCursor
                != firstResult.artifact.sourceCursor
        )
        #expect(
            secondResult.artifact.viewpoint.id
                == firstResult.artifact.viewpoint.id
        )
        #expect(
            secondResult.artifact.viewpoint.revision
                != firstResult.artifact.viewpoint.revision
        )
    }

    private func completedResult(
        from outcome: OfflineCaptureOutcome
    ) throws -> OfflineCaptureResult {
        guard case let .completed(result) = outcome else {
            Issue.record("Expected completed offline capture, received \(outcome)")
            throw UnexpectedOutcome()
        }
        return result
    }

    private func assertArtifact(
        _ artifact: RenderedImageArtifact,
        requestID: OffscreenRenderRequestID,
        cursor: SimulationCursor,
        viewpoint: RenderViewpoint,
        renderSettings: OffscreenRenderSettings,
        jpegSettings: JPEGEncodingSettings
    ) throws {
        #expect(artifact.format == .jpeg)
        #expect(!artifact.encodedData.isEmpty)
        #expect(artifact.sourceRequestID == requestID)
        #expect(artifact.sourceCursor == cursor)
        #expect(artifact.viewpoint == viewpoint)
        #expect(artifact.viewpoint.id == viewpoint.id)
        #expect(artifact.viewpoint.revision == viewpoint.revision)
        #expect(artifact.viewpoint.camera == viewpoint.camera)
        #expect(artifact.renderSettings == renderSettings)
        #expect(artifact.jpegSettings == jpegSettings)

        let source = try #require(
            CGImageSourceCreateWithData(artifact.encodedData as CFData, nil)
        )
        let typeIdentifier = try #require(CGImageSourceGetType(source))
        #expect(typeIdentifier as String == UTType.jpeg.identifier)

        let decodedImage = try #require(
            CGImageSourceCreateImageAtIndex(source, 0, nil)
        )
        #expect(decodedImage.width == renderSettings.size.width)
        #expect(decodedImage.height == renderSettings.size.height)
    }

    private struct UnexpectedOutcome: Error {}
}
