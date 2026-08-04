import Metal
import simd

/// Executes exact recorded presentation through the production Metal encoder.
///
/// Construction resolves pipelines, models, the three-slot frame ring, and all
/// size-dependent private targets. `run()` performs warm-up, drains it, then
/// measures exact projection/preparation, command recording/submission, GPU
/// feedback intervals, and end-to-end wall throughput without a view,
/// drawable, Simulation Runtime, Input Runtime, UI, or pixel readback.
final class RenderBenchmarkRunner {
    private static let requiredFrameSlotCount =
        MetalResourceStore.defaultFrameCount

    let configuration: RenderBenchmarkConfiguration

    private let workload: RenderBenchmarkWorkload
    private let resources: MetalResourceStore
    private let frameEncoder: MetalFrameEncoder
    private let frameSlots: [RenderBenchmarkFrameSlot]
    private let clock = ContinuousClock()
    private var terminalGPUError: RenderBenchmarkError?

    /// Selects the system Metal device and constructs all unmeasured resources.
    convenience init(
        renderAssetCatalog: RenderAssetCatalog,
        frames: [RenderBenchmarkFrame],
        configuration: RenderBenchmarkConfiguration
    ) throws(RenderBenchmarkError) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw .missingMetalDevice
        }

        try self.init(
            device: device,
            renderAssetCatalog: renderAssetCatalog,
            frames: frames,
            configuration: configuration
        )
    }

    /// Constructs the complete benchmark for an explicitly selected device.
    convenience init(
        device: any MTLDevice,
        renderAssetCatalog: RenderAssetCatalog,
        frames: [RenderBenchmarkFrame],
        configuration: RenderBenchmarkConfiguration
    ) throws(RenderBenchmarkError) {
        guard device.supportsFamily(.metal4) else {
            throw .metal4Unsupported
        }

        let resources: MetalResourceStore
        do {
            resources = try MetalResourceStore(
                device: device,
                renderAssetCatalog: renderAssetCatalog,
                frameCount: Self.requiredFrameSlotCount
            )
        } catch {
            throw .resourceConstructionFailed(String(describing: error))
        }

        try self.init(
            resources: resources,
            frames: frames,
            configuration: configuration
        )
    }

    /// Constructs a benchmark around an already prepared three-slot store.
    ///
    /// Injection supports focused integration tests and specialized hosts while
    /// keeping resource creation outside every warm-up and measured interval.
    /// Construction acquires each frame slot before preparing its targets. The
    /// caller must not submit other work through the store after handing it to
    /// the runner.
    init(
        resources: MetalResourceStore,
        frames: [RenderBenchmarkFrame],
        configuration: RenderBenchmarkConfiguration
    ) throws(RenderBenchmarkError) {
        guard resources.device.supportsFamily(.metal4) else {
            throw .metal4Unsupported
        }
        guard resources.frames.count == Self.requiredFrameSlotCount else {
            throw .invalidFrameResourceCount(
                expected: Self.requiredFrameSlotCount,
                actual: resources.frames.count
            )
        }

        let workload = try RenderBenchmarkWorkload(frames: frames)
        var frameSlots: [RenderBenchmarkFrameSlot] = []
        frameSlots.reserveCapacity(Self.requiredFrameSlotCount)
        for frameResources in resources.frames {
            frameSlots.append(
                try RenderBenchmarkFrameSlot(
                    frameResources: frameResources,
                    device: resources.device,
                    size: workload.pixelSize
                )
            )
        }

        self.configuration = configuration
        self.workload = workload
        self.resources = resources
        self.frameEncoder = MetalFrameEncoder(resources: resources)
        self.frameSlots = frameSlots
        self.terminalGPUError = nil
    }

    /// Runs and drains all warm-up work before measuring repeated workloads.
    func run() throws(RenderBenchmarkError) -> RenderBenchmarkResult {
        if let terminalGPUError {
            throw terminalGPUError
        }

        if configuration.warmupIterationCount > 0 {
            do {
                _ = try runPhase(
                    iterationCount: configuration.warmupIterationCount,
                    collectsSamples: false
                )
            } catch {
                latchGPUErrorIfNeeded(error)
                throw error
            }
        }

        let wallStart = clock.now
        let samples: [RenderBenchmarkSample]
        do {
            samples = try runPhase(
                iterationCount: configuration.measuredIterationCount,
                collectsSamples: true
            )
        } catch {
            latchGPUErrorIfNeeded(error)
            throw error
        }
        let wallDuration = wallStart.duration(to: clock.now)

        let expectedSampleCount = workload.frames.count
            * configuration.measuredIterationCount
        guard samples.count == expectedSampleCount else {
            throw .measuredSampleCountMismatch(
                expected: expectedSampleCount,
                actual: samples.count
            )
        }

        return RenderBenchmarkResult(
            configuration: configuration,
            pixelSize: workload.pixelSize,
            workloadFrameCount: workload.frames.count,
            wallDuration: wallDuration,
            samples: samples
        )
    }

    /// Submits complete ordered workload iterations and drains every callback.
    private func runPhase(
        iterationCount: Int,
        collectsSamples: Bool
    ) throws(RenderBenchmarkError) -> [RenderBenchmarkSample] {
        let tracker = RenderBenchmarkSubmissionTracker()
        var submissionIndex = 0

        do {
            for iteration in 0..<iterationCount {
                for benchmarkFrame in workload.frames {
                    try submit(
                        benchmarkFrame,
                        iteration: iteration,
                        submissionIndex: submissionIndex,
                        collectsSample: collectsSamples,
                        tracker: tracker
                    )
                    submissionIndex += 1
                }
            }
        } catch {
            let submissionError = error
            do {
                _ = try tracker.drain()
            } catch {
                throw error
            }
            throw submissionError
        }

        return try tracker.drain()
    }

    /// Performs measured CPU phases and transfers slot ownership at commit.
    private func submit(
        _ benchmarkFrame: RenderBenchmarkFrame,
        iteration: Int,
        submissionIndex: Int,
        collectsSample: Bool,
        tracker: RenderBenchmarkSubmissionTracker
    ) throws(RenderBenchmarkError) {
        let preparationStart = clock.now
        let preparedFrame = try prepare(benchmarkFrame)
        let projectionPreparationDuration = preparationStart.duration(
            to: clock.now
        )

        let slot = frameSlots[submissionIndex % frameSlots.count]
        let frameResources = slot.frameResources
        frameResources.waitUntilAvailable()
        var runnerOwnsFrameSlot = true
        defer {
            if runnerOwnsFrameSlot {
                frameResources.markAvailable()
            }
        }

        let recordingStart = clock.now
        frameResources.commandAllocator.reset()
        guard let commandBuffer = resources.device.makeCommandBuffer() else {
            throw .missingCommandBuffer(sequence: benchmarkFrame.sequence)
        }

        commandBuffer.beginCommandBuffer(
            allocator: frameResources.commandAllocator
        )
        commandBuffer.useResidencySet(slot.sceneTarget.residencySet)
        commandBuffer.useResidencySet(slot.targets.residencySet)

        do {
            let encodingInputs = try MetalFrameEncodingInputs(
                frameResources: frameResources,
                sceneColorTexture: slot.sceneTarget.texture,
                depthTexture: slot.targets.depthTexture,
                destinationTexture: slot.targets.destinationTexture,
                clearColor: benchmarkFrame.clearColor,
                outputMode: benchmarkFrame.settings.outputMode,
                exposure: benchmarkFrame.settings.exposure
            )
            try frameEncoder.encode(
                preparedFrame,
                inputs: encodingInputs,
                into: commandBuffer
            )
        } catch {
            commandBuffer.endCommandBuffer()
            throw .frameEncodingFailed(
                sequence: benchmarkFrame.sequence,
                description: String(describing: error)
            )
        }
        commandBuffer.endCommandBuffer()

        try tracker.registerSubmission()
        let submission = RenderBenchmarkSubmission(
            resources: resources,
            encoder: frameEncoder,
            commandBuffer: commandBuffer,
            slot: slot,
            tracker: tracker,
            iteration: iteration,
            sequence: benchmarkFrame.sequence,
            projectionPreparationDuration:
                projectionPreparationDuration,
            collectsSample: collectsSample
        )
        let commitOptions = MTL4CommitOptions()
        commitOptions.addFeedbackHandler { feedback in
            submission.complete(
                feedbackError: feedback.error,
                gpuStartTime: feedback.gpuStartTime,
                gpuEndTime: feedback.gpuEndTime
            )
        }

        runnerOwnsFrameSlot = false
        resources.commandQueue.commit(
            [commandBuffer],
            options: commitOptions
        )
        submission.recordingDidFinish(
            duration: recordingStart.duration(to: clock.now)
        )
    }

    /// Projects and resolves one exact frame without touching mutable GPU state.
    private func prepare(
        _ benchmarkFrame: RenderBenchmarkFrame
    ) throws(RenderBenchmarkError) -> MetalPreparedFrame {
        let renderFrame: RenderFrame
        do {
            renderFrame = try RenderFrame(
                exactlyProjecting: benchmarkFrame.presentationSnapshot,
                viewpoint: benchmarkFrame.viewpoint
            )
        } catch {
            switch error {
            case .invalidSelectedCamera:
                throw .invalidViewpoint(sequence: benchmarkFrame.sequence)

            case .missingPosition,
                 .unsupportedNormalTransform,
                 .nonfiniteModelViewTransform,
                 .nonfiniteModelViewProjectionTransform:
                throw .invalidPresentation(
                    sequence: benchmarkFrame.sequence,
                    reason: error
                )
            }
        }

        let projectionMatrix = benchmarkFrame.viewpoint.camera
            .projectionMatrix(
                aspectRatio: benchmarkFrame.settings.size.aspectRatio
            )
        guard (
            projectionMatrix * benchmarkFrame.viewpoint.camera.viewMatrix
        ).hasFiniteElements else {
            throw .invalidViewpoint(sequence: benchmarkFrame.sequence)
        }
        for (entity, instance) in zip(
            benchmarkFrame.presentationSnapshot.entityPresentations,
            renderFrame.instances
        ) {
            guard (
                projectionMatrix * instance.modelViewMatrix
            ).hasFiniteElements else {
                throw .invalidPresentation(
                    sequence: benchmarkFrame.sequence,
                    reason: .nonfiniteModelViewProjectionTransform(
                        entityID: entity.id
                    )
                )
            }
        }
        guard renderFrame.instances.count <= FrameResources.maximumInstanceCount
        else {
            throw .instanceLimitExceeded(
                sequence: benchmarkFrame.sequence,
                requested: renderFrame.instances.count,
                maximum: FrameResources.maximumInstanceCount
            )
        }

        let preparedFrame = frameEncoder.prepare(renderFrame)
        for instance in preparedFrame.instances {
            let meshID = instance.renderInstance.meshID
            guard let model = instance.model else {
                throw .missingModel(
                    sequence: benchmarkFrame.sequence,
                    meshID: meshID
                )
            }
            guard model.hasCompleteDrawableIndexedGeometry else {
                throw .incompleteModel(
                    sequence: benchmarkFrame.sequence,
                    meshID: meshID
                )
            }
        }
        return preparedFrame
    }

    private func latchGPUErrorIfNeeded(_ error: RenderBenchmarkError) {
        guard error.isGPUFeedbackFailure else {
            return
        }

        terminalGPUError = error
    }
}
