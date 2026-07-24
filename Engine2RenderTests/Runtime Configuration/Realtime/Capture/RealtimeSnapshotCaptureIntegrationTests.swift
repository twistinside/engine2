import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Engine2

struct RealtimeSnapshotCaptureIntegrationTests {
    @Test @MainActor
    func capturesLivePresentationThroughMetalWithoutAdvancingSimulation() async throws {
        let gameContent = BasicGameContent()
        let assembly = RealtimeConfiguration(
            pollInterval: .seconds(60)
        ).makeAssembly(gameContent: gameContent)
        let sourceSnapshot =
            assembly.simulationRuntime.latestPresentationSnapshot
        let sourceCursor = assembly.simulationRuntime.currentCursor
        let renderRuntime = try MetalOffscreenRenderRuntime(
            catalog: gameContent.renderAssetCatalog
        )
        let connection = RealtimeSnapshotCaptureConnection(
            presentationSource: assembly.simulationRuntime,
            viewpointSource: assembly.screenViewpointController,
            renderTarget: renderRuntime
        )
        let renderSettings = OffscreenRenderSettings(
            size: try RenderPixelSize(width: 96, height: 64),
            outputMode: .surface,
            exposure: .validation
        )
        let request = RealtimeSnapshotCaptureRequest(
            renderRequestID: OffscreenRenderRequestID(),
            renderSettings: renderSettings,
            jpegSettings: JPEGEncodingSettings(quality: .maximum)
        )

        let outcome = await connection.capture(request)
        guard case let .completed(selectedSnapshot, artifact) = outcome else {
            Issue.record("Expected completed live snapshot capture, received \(outcome)")
            return
        }

        #expect(selectedSnapshot == sourceSnapshot)
        #expect(assembly.simulationRuntime.currentCursor == sourceCursor)
        #expect(artifact.sourceCursor == sourceCursor)
        #expect(artifact.sourceRequestID == request.renderRequestID)
        #expect(artifact.renderSettings == renderSettings)
        #expect(
            artifact.viewpoint
                == assembly.screenViewpointController.resolveViewpoint(
                    defaultCamera: sourceSnapshot.camera
                )
        )

        let imageSource = try #require(
            CGImageSourceCreateWithData(artifact.encodedData as CFData, nil)
        )
        let typeIdentifier = try #require(CGImageSourceGetType(imageSource))
        #expect(typeIdentifier as String == UTType.jpeg.identifier)

        let image = try #require(
            CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        )
        #expect(image.width == renderSettings.size.width)
        #expect(image.height == renderSettings.size.height)
    }
}
