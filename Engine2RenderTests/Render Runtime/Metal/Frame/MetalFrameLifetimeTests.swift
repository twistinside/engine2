import Dispatch
import Metal
import QuartzCore
import Testing
@testable import Engine2

struct MetalFrameLifetimeTests {
    @MainActor
    @Test func feedbackGatesResizeAndTokenRetainsTheExactOldTarget() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let resources = try MetalResourceStore(
            device: device,
            renderAssetCatalog: .materialOnlyTestCatalog,
            frameCount: 1
        )
        let frame = try #require(resources.frames.first)
        let drawable = try makeDrawable(device: device)
        let errorState = MetalRenderErrorState()

        // Own the sole frame slot exactly as `MetalRenderer.draw(in:)` does,
        // then install the first drawable-sized target into that slot.
        frame.waitUntilAvailable()
        var oldTarget: MetalHDRSceneTarget? = try frame.prepareHDRSceneTarget(
            device: device,
            width: 16,
            height: 16
        )
        let weakOldTarget = TestWeakReference(oldTarget)
        var submission: MetalInFlightSubmission? = MetalInFlightSubmission(
            resources: resources,
            drawable: drawable,
            depthTexture: nil,
            sceneTarget: try #require(oldTarget),
            frame: frame,
            errorState: errorState
        )

        // A second owner must not acquire this slot before completion feedback.
        // The background waiter mirrors a later draw without blocking this
        // test's main actor, where Metal target creation belongs.
        let waiterStarted = DispatchSemaphore(value: 0)
        let waiterAcquired = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            waiterStarted.signal()
            frame.waitUntilAvailable()
            waiterAcquired.signal()
            frame.markAvailable()
        }
        #expect(waiterStarted.wait(timeout: .now() + 1) == .success)
        #expect(waiterAcquired.wait(timeout: .now() + 0.05) == .timedOut)

        // Production feedback records any error before it releases the slot.
        // Successful completion wakes the blocked later owner here.
        submission?.complete(feedbackError: nil)
        #expect(waiterAcquired.wait(timeout: .now() + 1) == .success)

        // Reacquire the returned slot before resizing it. Replacement removes
        // the frame's strong reference to the old target, but the in-flight
        // token must still retain that exact generation until the feedback
        // closure itself releases the token.
        frame.waitUntilAvailable()
        defer { frame.markAvailable() }
        let replacement = try frame.prepareHDRSceneTarget(
            device: device,
            width: 32,
            height: 24
        )
        #expect(replacement !== oldTarget)

        oldTarget = nil
        #expect(weakOldTarget.value != nil)
        submission = nil
        #expect(weakOldTarget.value == nil)
        #expect(frame.hdrSceneTarget === replacement)
    }

    @MainActor
    private func makeDrawable(
        device: any MTLDevice
    ) throws -> any CAMetalDrawable {
        let layer = CAMetalLayer()
        layer.device = device
        layer.pixelFormat = MetalFrameEncoder.destinationColorPixelFormat
        layer.drawableSize = CGSize(width: 16, height: 16)

        // An unattached layer still supplies a real CAMetalDrawable on the
        // supported macOS Metal device, avoiding a fake lifetime object that
        // could diverge from the production submission token's ownership.
        return try #require(layer.nextDrawable())
    }
}
