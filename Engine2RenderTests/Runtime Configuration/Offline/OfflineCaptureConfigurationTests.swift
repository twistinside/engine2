import CoreGraphics
import Foundation
import ImageIO
import simd
import Testing
import UniformTypeIdentifiers
@testable import Engine2

struct OfflineCaptureConfigurationTests {
    @Test
    func composesSimulationMetalAndImageArtifactsAcrossCaptures() async throws {
        let sessionUUID = UUID(
            uuidString: "40000000-0000-0000-0000-000000000001"
        )!
        let sessionID = SimulationSessionID(
            rawValue: sessionUUID
        )
        let configuration = OfflineCaptureConfiguration(
            renderLimits: .conservative
        )
        let gameContent = BasicGameContent()
        let assembly = try configuration.makeAssembly(
            gameContent: gameContent,
            sessionID: sessionID
        )
        let captureTarget = assembly.captureTarget

        let viewpointUUID = UUID(
            uuidString: "40000000-0000-0000-0000-000000000002"
        )!
        let viewpointID = RenderViewpointID(
            rawValue: viewpointUUID
        )
        let firstViewpointRevision = RenderViewpointRevision(rawValue: 7)
        let cameraUp = SIMD3<Float>(0, 1, 0)
        let firstCamera = Camera.lookingAt(
            .zero,
            from: SIMD3<Float>(0, 0, 8),
            up: cameraUp,
            projection: .standardPerspective
        )
        let firstViewpoint = RenderViewpoint(
            id: viewpointID,
            revision: firstViewpointRevision,
            camera: firstCamera
        )
        let firstRenderSize = try RenderPixelSize(width: 96, height: 64)
        let firstRenderSettings = OffscreenRenderSettings(
            size: firstRenderSize,
            outputMode: .surface,
            exposure: .validation
        )
        let firstJPEGQuality = try JPEGQuality(0.72)
        let firstEncoding = ImageArtifactEncoding.jpeg(
            quality: firstJPEGQuality
        )
        let firstAdvanceRequest = SimulationAdvanceRequest(
            expectedCursor: assembly.initialCursor,
            stepCount: .one,
            inputAssignment: .none
        )
        let firstRenderRequestUUID = UUID(
            uuidString: "40000000-0000-0000-0000-000000000003"
        )!
        let firstRenderRequestID = OffscreenRenderRequestID(
            rawValue: firstRenderRequestUUID
        )
        let firstRequest = OfflineCaptureRequest(
            advanceRequest: firstAdvanceRequest,
            renderRequestID: firstRenderRequestID,
            viewpoint: firstViewpoint,
            renderSettings: firstRenderSettings,
            encoding: firstEncoding
        )

        // The public assembly boundary performs real fixed-step Simulation,
        // real Metal offscreen submission/readback, then real Image I/O
        // derivation without exposing any concrete Runtime references.
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
            encoding: firstEncoding
        )

        let secondCamera = Camera.lookingAt(
            .zero,
            from: SIMD3<Float>(1, 0.5, 8),
            up: cameraUp,
            projection: .standardPerspective
        )
        let secondViewpoint = RenderViewpoint(
            id: viewpointID,
            revision: firstViewpoint.revision.advanced(),
            camera: secondCamera
        )
        let secondRenderSize = try RenderPixelSize(width: 80, height: 60)
        let secondExposure = ManualExposure(multiplier: 1.25)
        let secondRenderSettings = OffscreenRenderSettings(
            size: secondRenderSize,
            outputMode: .viewSpaceNormals,
            exposure: secondExposure
        )
        let secondEncoding = ImageArtifactEncoding.png
        let secondStepCount = SimulationStepCount(rawValue: 2)
        let secondAdvanceRequest = SimulationAdvanceRequest(
            expectedCursor: firstResult.advanceResult.finalCursor,
            stepCount: secondStepCount,
            inputAssignment: .none
        )
        let secondRenderRequestUUID = UUID(
            uuidString: "40000000-0000-0000-0000-000000000004"
        )!
        let secondRenderRequestID = OffscreenRenderRequestID(
            rawValue: secondRenderRequestUUID
        )
        let secondRequest = OfflineCaptureRequest(
            advanceRequest: secondAdvanceRequest,
            renderRequestID: secondRenderRequestID,
            viewpoint: secondViewpoint,
            renderSettings: secondRenderSettings,
            encoding: secondEncoding
        )

        let secondResult = try completedResult(
            from: await captureTarget.capture(secondRequest)
        )
        let expectedSecondInitialTick = SimulationTick(rawValue: 1)
        let expectedSecondFinalTick = SimulationTick(rawValue: 3)

        // The first outcome is the only cursor authority needed to issue the
        // next request. No hidden Runtime read or latest-value sample is used.
        #expect(
            secondResult.advanceResult.initialCursor
                == firstResult.advanceResult.finalCursor
        )
        #expect(
            secondResult.advanceResult.initialCursor.tick
                == expectedSecondInitialTick
        )
        #expect(
            secondResult.advanceResult.finalCursor.tick
                == expectedSecondFinalTick
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
            encoding: secondEncoding
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

    private func completedResult(from outcome: OfflineCaptureOutcome) throws -> OfflineCaptureResult {
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
        encoding: ImageArtifactEncoding
    ) throws {
        #expect(!artifact.encodedData.isEmpty)
        #expect(artifact.sourceRequestID == requestID)
        #expect(artifact.sourceCursor == cursor)
        #expect(artifact.viewpoint == viewpoint)
        #expect(artifact.viewpoint.id == viewpoint.id)
        #expect(artifact.viewpoint.revision == viewpoint.revision)
        #expect(artifact.viewpoint.camera == viewpoint.camera)
        #expect(artifact.renderSettings == renderSettings)
        #expect(artifact.encoding == encoding)

        let expectedType: UTType
        switch encoding {
        case .jpeg:
            expectedType = .jpeg
            let filePrefix = Array(artifact.encodedData.prefix(2))
            let fileSuffix = Array(artifact.encodedData.suffix(2))
            #expect(filePrefix == [0xFF, 0xD8])
            #expect(fileSuffix == [0xFF, 0xD9])
        case .png:
            expectedType = .png
            let filePrefix = Array(artifact.encodedData.prefix(8))
            #expect(
                filePrefix
                    == [
                        0x89, 0x50, 0x4E, 0x47,
                        0x0D, 0x0A, 0x1A, 0x0A
                    ]
            )
        }
        let source = try #require(
            CGImageSourceCreateWithData(artifact.encodedData as CFData, nil)
        )
        let typeIdentifier = try #require(CGImageSourceGetType(source))
        #expect(typeIdentifier as String == expectedType.identifier)

        let decodedImage = try #require(
            CGImageSourceCreateImageAtIndex(source, 0, nil)
        )
        #expect(decodedImage.width == renderSettings.size.width)
        #expect(decodedImage.height == renderSettings.size.height)
    }

    private struct UnexpectedOutcome: Error {}
}
