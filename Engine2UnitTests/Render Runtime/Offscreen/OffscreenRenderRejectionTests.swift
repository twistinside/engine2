import Testing
@testable import Engine2

struct OffscreenRenderRejectionTests {
    private nonisolated static let entityProjectionErrors: [RenderFrameProjectionError] = {
        let missingPositionEntityID = EntityID(index: 1, generation: 2)
        let unsupportedNormalEntityID = EntityID(index: 3, generation: 4)
        let nonfiniteModelViewEntityID = EntityID(index: 5, generation: 6)
        let nonfiniteProjectionEntityID = EntityID(index: 7, generation: 8)
        return [
            .missingPosition(entityID: missingPositionEntityID),
            .unsupportedNormalTransform(entityID: unsupportedNormalEntityID),
            .nonfiniteModelViewTransform(entityID: nonfiniteModelViewEntityID),
            .nonfiniteModelViewProjectionTransform(entityID: nonfiniteProjectionEntityID)
        ]
    }()

    @Test func classifiesSelectedCameraFailureAsAnInvalidViewpoint() {
        let rejection = OffscreenRenderRejection(.invalidSelectedCamera)
        #expect(rejection == .invalidViewpoint)
    }

    @Test(arguments: Self.entityProjectionErrors)
    func classifiesEntityFailuresAsInvalidPresentation(_ projectionError: RenderFrameProjectionError) {
        let rejection = OffscreenRenderRejection(projectionError)
        #expect(rejection == .invalidPresentation(projectionError))
    }
}
