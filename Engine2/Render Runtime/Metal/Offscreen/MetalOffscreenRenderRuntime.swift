import Metal
import simd

/// Metal 4 backend for exact caller-driven offscreen render requests.
///
/// This Runtime owns one device-scoped resource store, one reusable frame
/// encoder, and exactly one frame slot. It never samples a live source, advances
/// Simulation, acquires a drawable, or encodes an artifact format. The caller
/// supplies the completed Simulation snapshot and explicit viewpoint by value;
/// the completed result contains detached BGRA8-sRGB pixels with matching
/// provenance.
@MainActor
final class MetalOffscreenRenderRuntime: POffscreenRenderTarget {
    /// Long-lived backend resources shared by every accepted request.
    private let resources: MetalResourceStore

    /// Sole reusable frame slot proved present during Runtime construction.
    private let frame: FrameResources

    /// App-selected allocation and readback policy for this capability.
    let limits: OffscreenRenderLimits

    private let frameEncoder: MetalFrameEncoder
    private(set) var renderingState = MetalOffscreenRenderState.ready

    /// Selects the system Metal device and constructs a one-slot offscreen store.
    convenience init(catalog: RenderAssetCatalog, limits: OffscreenRenderLimits) throws {
        let resources = try MetalResourceStore(
            renderAssetCatalog: catalog,
            frameCount: 1
        )
        try self.init(resources: resources, limits: limits)
    }

    /// Constructs an offscreen Runtime around an injected one-slot store.
    ///
    /// Injection keeps device selection and expensive resource construction
    /// controllable for integration tests while preserving the production
    /// single-request back-pressure policy.
    init(resources: MetalResourceStore, limits: OffscreenRenderLimits) throws(MetalOffscreenRenderTargetError) {
        guard resources.frames.count == 1, let frame = resources.frames.first else {
            throw MetalOffscreenRenderTargetError.invalidFrameResourceCount(resources.frames.count)
        }

        self.resources = resources
        self.frame = frame
        self.limits = limits
        self.frameEncoder = MetalFrameEncoder(resources: resources)
    }

    /// Transports an immutable request into the Runtime's serialized actor.
    nonisolated func render(_ request: OffscreenRenderRequest) async -> OffscreenRenderOutcome {
        await renderOnMainActor(request)
    }

    /// Admits and immutably preflights one exact request under the busy gate.
    private func renderOnMainActor(_ request: OffscreenRenderRequest) async -> OffscreenRenderOutcome {
        // One explicit request may own the sole allocator and mutable frame
        // buffers at a time. Refusal is immediate rather than an implicit queue.
        switch renderingState {
        case .ready:
            break

        case .rendering:
            return .rejected(.runtimeBusy)

        case let .failed(failure):
            // A driver failure makes allocator and queue state unsafe to reuse.
            // Preserve and replay the original failure without touching Metal.
            return .failed(failure)
        }

        guard !Task.isCancelled else {
            return .rejected(.cancelledBeforeSubmission)
        }

        guard limits.permits(request.settings.size) else {
            return .rejected(
                .exceedsLimits(
                    requested: request.settings.size,
                    limits: limits
                )
            )
        }

        // Exact projection must account for every published entity. Translate
        // malformed presentation into an expected refusal before instance,
        // model, material, or mutable-GPU-resource preflight begins.
        let renderFrame: RenderFrame
        do {
            renderFrame = try RenderFrame(
                exactlyProjecting: request.presentationSnapshot,
                viewpoint: request.viewpoint
            )
        } catch {
            let rejection = OffscreenRenderRejection(error)
            return .rejected(rejection)
        }

        // Projection shape is output-specific. Camera construction validates
        // its authored projection, while this check catches finite view and
        // projection matrices whose product overflows for the requested size.
        let projectionMatrix = request.viewpoint.camera.projectionMatrix(
            aspectRatio: request.settings.size.aspectRatio
        )
        guard (projectionMatrix * request.viewpoint.camera.viewMatrix)
            .hasFiniteElements else {
            return .rejected(.invalidViewpoint)
        }

        // GPU packing multiplies projection by each retained validated
        // model-view matrix after frame admission. Prove those output-shaped
        // products remain finite so an accepted offline request cannot write
        // NaNs for one extreme entity.
        for (entity, instance) in zip(
            request.presentationSnapshot.entityPresentations,
            renderFrame.instances
        ) {
            guard (projectionMatrix * instance.modelViewMatrix).hasFiniteElements else {
                return .rejected(
                    .invalidPresentation(
                        .nonfiniteModelViewProjectionTransform(
                            entityID: entity.id
                        )
                    )
                )
            }
        }
        guard renderFrame.instances.count <= FrameResources.maximumInstanceCount
        else {
            return .rejected(
                .instanceLimitExceeded(
                    requested: renderFrame.instances.count,
                    maximum: FrameResources.maximumInstanceCount
                )
            )
        }

        // Resolve all authored content before acquiring the mutable frame slot,
        // resetting its allocator, or creating request-scoped GPU targets.
        let preparedFrame = frameEncoder.prepare(renderFrame)

        // The live screen may deliberately omit an instance whose optional
        // model is unavailable. Exact offline work cannot silently produce a
        // partial image, so validate the exact prepared model values that
        // encoding will consume rather than repeating store lookups.
        for instance in preparedFrame.instances {
            let meshID = instance.renderInstance.meshID

            guard let model = instance.model else {
                return failure(
                    at: .preparation,
                    causedBy: MetalOffscreenRenderTargetError.missingModel(meshID)
                )
            }

            guard model.hasCompleteDrawableIndexedGeometry else {
                return failure(
                    at: .preparation,
                    causedBy: MetalOffscreenRenderTargetError
                        .modelHasIncompleteDrawableIndexedGeometry(
                            meshID
                        )
                )
            }
        }

        guard !Task.isCancelled else {
            return .rejected(.cancelledBeforeSubmission)
        }

        renderingState = .rendering
        return await renderPreparedFrame(preparedFrame, for: request)
    }

    /// Executes one admitted request while the Runtime owns its busy gate.
    ///
    /// The caller has completed immutable preflight and entered `.rendering`
    /// without suspension. This method owns request-scoped targets, the sole
    /// frame slot, command encoding and submission, feedback, and readback.
    private func renderPreparedFrame(_ preparedFrame: MetalPreparedFrame, for request: OffscreenRenderRequest) async -> OffscreenRenderOutcome {
        defer {
            if renderingState == .rendering {
                renderingState = .ready
            }
        }

        let targets: MetalOffscreenRenderTargets
        do {
            targets = try MetalOffscreenRenderTargets(
                device: resources.device,
                size: request.settings.size
            )
        } catch {
            return failure(at: .targetAllocation, causedBy: error)
        }

        guard !Task.isCancelled else {
            return .rejected(.cancelledBeforeSubmission)
        }

        // The busy gate and completion-awaited lifecycle prove the sole slot is
        // available here. Keep the semaphore boundary nevertheless so the same
        // frame-resource invariant is enforced as in screen rendering.
        frame.waitUntilAvailable()
        var runtimeOwnsFrame = true
        defer {
            if runtimeOwnsFrame {
                frame.markAvailable()
            }
        }

        let sceneTarget: MetalHDRSceneTarget
        do {
            sceneTarget = try frame.prepareHDRSceneTarget(
                device: resources.device,
                width: request.settings.size.width,
                height: request.settings.size.height
            )
        } catch {
            return failure(at: .targetAllocation, causedBy: error)
        }

        guard !Task.isCancelled else {
            return .rejected(.cancelledBeforeSubmission)
        }

        frame.commandAllocator.reset()
        guard let commandBuffer = resources.device.makeCommandBuffer() else {
            return failure(
                at: .commandBufferCreation,
                causedBy: MetalOffscreenRenderTargetError.missingCommandBuffer
            )
        }

        commandBuffer.beginCommandBuffer(allocator: frame.commandAllocator)
        commandBuffer.useResidencySet(sceneTarget.residencySet)
        commandBuffer.useResidencySet(targets.residencySet)

        let clearColor = MTLClearColor(
            red: 0,
            green: 0,
            blue: 0,
            alpha: 1
        )
        do {
            let encodingInputs = try MetalFrameEncodingInputs(
                frameResources: frame,
                sceneColorTexture: sceneTarget.texture,
                depthTexture: targets.depthTexture,
                destinationTexture: targets.destinationTexture,
                clearColor: clearColor,
                outputMode: request.settings.outputMode,
                exposure: request.settings.exposure
            )
            try frameEncoder.encode(
                preparedFrame,
                inputs: encodingInputs,
                into: commandBuffer
            )
        } catch {
            commandBuffer.endCommandBuffer()
            return failure(at: .encoding, causedBy: error)
        }
        commandBuffer.endCommandBuffer()

        // This is the final cancellation boundary before submission. No actor
        // suspension occurs between this check and the queue commit below.
        guard !Task.isCancelled else {
            return .rejected(.cancelledBeforeSubmission)
        }

        // From this point queue feedback owns slot release. Task cancellation
        // deliberately does not short-circuit the continuation or resource
        // retention: Metal 4 command buffers do not retain this object graph.
        runtimeOwnsFrame = false
        do {
            try await commit(
                commandBuffer,
                frame: frame,
                sceneTarget: sceneTarget,
                targets: targets
            )
        } catch {
            let failure = OffscreenRenderFailure(
                stage: .gpuExecution,
                backendDescription: error.backendDescription
            )
            renderingState = .failed(failure)
            return .failed(failure)
        }

        // Cancellation after submission still waited for actual feedback and
        // released the frame slot. Skip the potentially large CPU allocation
        // and texture readback when the original caller no longer wants it.
        guard !Task.isCancelled else {
            return .cancelledAfterSubmission(requestID: request.id)
        }

        let image: RenderedBGRA8SRGBImage
        do {
            image = try targets.readback()
        } catch {
            return failure(at: .readback, causedBy: error)
        }

        let result = OffscreenRenderResult(
            requestID: request.id,
            sourceCursor: request.presentationSnapshot.cursor,
            viewpoint: request.viewpoint,
            settings: request.settings,
            image: image
        )
        return .completed(result)
    }

    /// Commits one closed buffer and waits for real queue feedback.
    ///
    /// The feedback closure is the sole owner of frame-slot release after
    /// submission. Its token also retains every object referenced by the GPU.
    private func commit(
        _ commandBuffer: any MTL4CommandBuffer,
        frame: FrameResources,
        sceneTarget: MetalHDRSceneTarget,
        targets: MetalOffscreenRenderTargets
    ) async throws(MetalOffscreenSubmissionError) {
        try await withCheckedThrowingContinuation { continuation in
            let submission = MetalOffscreenSubmission(
                resources: resources,
                encoder: frameEncoder,
                frame: frame,
                commandBuffer: commandBuffer,
                sceneTarget: sceneTarget,
                targets: targets,
                continuation: continuation
            )
            let commitOptions = MTL4CommitOptions()
            commitOptions.addFeedbackHandler { feedback in
                submission.complete(feedbackError: feedback.error)
            }
            resources.commandQueue.commit(
                [commandBuffer],
                options: commitOptions
            )
        }
    }

    /// Maps a backend error into a stable accepted-request failure stage.
    private func failure(at stage: OffscreenRenderFailureStage, causedBy error: any Error) -> OffscreenRenderOutcome {
        let backendDescription = String(describing: error)
        let failure = OffscreenRenderFailure(
            stage: stage,
            backendDescription: backendDescription
        )
        return .failed(failure)
    }
}
