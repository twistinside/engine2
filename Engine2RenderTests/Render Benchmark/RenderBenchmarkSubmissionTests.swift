import Dispatch
import Metal
import Testing
@testable import Engine2

struct RenderBenchmarkSubmissionTests {
    @Test func duplicateFeedbackReleasesFrameSlotAndCompletesTrackerOnce() throws {
        let fixture = try RenderBenchmarkTestFixture()
        let resources = try MetalResourceStore(
            renderAssetCatalog: fixture.catalog,
            frameCount: MetalResourceStore.defaultFrameCount
        )
        let frame = try #require(resources.frames.first)
        let slot = try RenderBenchmarkFrameSlot(
            frameResources: frame,
            device: resources.device,
            size: fixture.pixelSize
        )
        let encoder = MetalFrameEncoder(resources: resources)
        let commandBuffer = try #require(
            resources.device.makeCommandBuffer()
        )
        let tracker = RenderBenchmarkSubmissionTracker()

        frame.waitUntilAvailable()
        try tracker.registerSubmission()
        let submission = RenderBenchmarkSubmission(
            resources: resources,
            encoder: encoder,
            commandBuffer: commandBuffer,
            slot: slot,
            tracker: tracker,
            iteration: 0,
            sequence: 3,
            projectionPreparationDuration: .milliseconds(1),
            collectsSample: true
        )
        submission.recordingDidFinish(duration: .milliseconds(2))
        submission.complete(
            feedbackError: nil,
            gpuStartTime: 10,
            gpuEndTime: 10.003
        )
        submission.complete(
            feedbackError: nil,
            gpuStartTime: 11,
            gpuEndTime: 11.004
        )

        let samples = try tracker.drain()
        #expect(samples.count == 1)
        #expect(samples[0].sequence == 3)
        #expect(
            abs(samples[0].gpuDuration.milliseconds - 3) < 0.000_001
        )

        // Consume the single feedback release, then prove duplicate feedback
        // did not leave another semaphore permit behind.
        frame.waitUntilAvailable()
        let waiterAcquired = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            frame.waitUntilAvailable()
            waiterAcquired.signal()
            frame.markAvailable()
        }
        #expect(
            waiterAcquired.wait(timeout: .now() + 0.05) == .timedOut
        )
        frame.markAvailable()
        #expect(
            waiterAcquired.wait(timeout: .now() + 1) == .success
        )
    }

    @Test func trackerLatchesFirstGPUFailureThroughDrainAndAdmission() throws {
        let tracker = RenderBenchmarkSubmissionTracker()
        let expected = RenderBenchmarkError.gpuExecutionFailed(
            sequence: 8,
            description: "synthetic failure"
        )

        try tracker.registerSubmission()
        tracker.complete(sample: nil, error: expected)

        #expect(throws: expected) {
            try tracker.drain()
        }
        #expect(throws: expected) {
            try tracker.registerSubmission()
        }
    }
}
