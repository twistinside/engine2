import Foundation
import Metal

/// Retains one complete submitted Metal object graph until queue feedback.
///
/// Metal 4 residency does not retain Swift owners. The feedback closure keeps
/// this token alive, and the token retains the resource store, encoder,
/// command buffer, exact frame slot, and persistent targets. Feedback releases
/// the slot exactly once even if an erroneous duplicate callback occurs.
nonisolated final class RenderBenchmarkSubmission: @unchecked Sendable {
    private let resources: MetalResourceStore
    private let encoder: MetalFrameEncoder
    private let commandBuffer: any MTL4CommandBuffer
    private let frame: FrameResources
    private let sceneTarget: MetalHDRSceneTarget
    private let targets: RenderBenchmarkTargets
    private let tracker: RenderBenchmarkSubmissionTracker
    private let iteration: Int
    private let sequence: UInt64
    private let projectionPreparationDuration: Duration
    private let collectsSample: Bool

    private let stateLock = NSLock()
    private var recordingSubmissionDuration: Duration?
    private var gpuDuration: Duration?
    private var feedbackError: RenderBenchmarkError?
    private var hasFeedback = false
    private var didFinalize = false

    @MainActor
    init(
        resources: MetalResourceStore,
        encoder: MetalFrameEncoder,
        commandBuffer: any MTL4CommandBuffer,
        slot: RenderBenchmarkFrameSlot,
        tracker: RenderBenchmarkSubmissionTracker,
        iteration: Int,
        sequence: UInt64,
        projectionPreparationDuration: Duration,
        collectsSample: Bool
    ) {
        self.resources = resources
        self.encoder = encoder
        self.commandBuffer = commandBuffer
        self.frame = slot.frameResources
        self.sceneTarget = slot.sceneTarget
        self.targets = slot.targets
        self.tracker = tracker
        self.iteration = iteration
        self.sequence = sequence
        self.projectionPreparationDuration = projectionPreparationDuration
        self.collectsSample = collectsSample
    }

    /// Supplies the CPU interval whose endpoint follows the actual queue commit.
    nonisolated func recordingDidFinish(duration: Duration) {
        stateLock.lock()
        precondition(
            recordingSubmissionDuration == nil,
            "A benchmark submission can record its CPU duration only once."
        )
        recordingSubmissionDuration = duration
        stateLock.unlock()

        finalizeIfReady()
    }

    /// Consumes one Metal 4 feedback record and releases the frame slot once.
    nonisolated func complete(
        feedbackError: (any Error)?,
        gpuStartTime: Double,
        gpuEndTime: Double
    ) {
        stateLock.lock()
        guard !hasFeedback else {
            stateLock.unlock()
            return
        }
        hasFeedback = true

        if let feedbackError {
            self.feedbackError = .gpuExecutionFailed(
                sequence: sequence,
                description: String(describing: feedbackError)
            )
        } else if !gpuStartTime.isFinite
                    || !gpuEndTime.isFinite
                    || gpuStartTime < 0
                    || gpuEndTime < gpuStartTime {
            self.feedbackError = .invalidGPUInterval(
                sequence: sequence,
                startSeconds: gpuStartTime,
                endSeconds: gpuEndTime
            )
        } else {
            gpuDuration = .seconds(gpuEndTime - gpuStartTime)
        }
        stateLock.unlock()

        frame.markAvailable()
        finalizeIfReady()
    }

    private nonisolated func finalizeIfReady() {
        stateLock.lock()
        guard !didFinalize,
              hasFeedback,
              let recordingSubmissionDuration
        else {
            stateLock.unlock()
            return
        }
        didFinalize = true

        let error = feedbackError
        let sample: RenderBenchmarkSample?
        if collectsSample, error == nil, let gpuDuration {
            sample = RenderBenchmarkSample(
                iteration: iteration,
                sequence: sequence,
                projectionPreparationDuration:
                    projectionPreparationDuration,
                recordingSubmissionDuration: recordingSubmissionDuration,
                gpuDuration: gpuDuration
            )
        } else {
            sample = nil
        }
        stateLock.unlock()

        tracker.complete(sample: sample, error: error)
    }
}
