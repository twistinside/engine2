import Foundation
import simd

/// Owns an optional free-orbit viewpoint for one interactive screen output.
///
/// The controller is presentation state rather than Simulation state. Until a
/// meaningful presentation gesture arrives it passes through the latest
/// Simulation-authored camera exactly. Its first gesture seeds orbit state from
/// that latest default, after which the screen can continue moving while the
/// Simulation cursor is frozen.
@MainActor
final class ScreenViewpointController: PRenderViewpointSource {
    /// Stable identity of the screen viewpoint across camera revisions.
    let id: RenderViewpointID

    /// Current version of this controller's output-owned state.
    private(set) var revision: RenderViewpointRevision = .zero

    /// World-space point around which horizontal drag input orbits.
    let target: SIMD3<Float>

    /// Radians of yaw applied per point of horizontal pointer motion.
    let pointerOrbitSensitivity: Float

    /// World-space radius change applied per point of vertical scroll motion.
    let scrollZoomSensitivity: Float

    /// Smallest permitted horizontal orbit radius.
    let minimumRadius: Float

    /// Largest permitted horizontal orbit radius.
    let maximumRadius: Float

    private var overriddenCamera: Camera?
    private var yaw: Float?
    private var radius: Float?
    private var verticalTargetOffset: Float?
    private var projection: Camera.Projection?

    init(
        id: RenderViewpointID = RenderViewpointID(),
        target: SIMD3<Float> = .zero,
        pointerOrbitSensitivity: Float = 0.01,
        scrollZoomSensitivity: Float = 0.04,
        minimumRadius: Float = 2,
        maximumRadius: Float = 30
    ) {
        precondition(
            target.x.isFinite && target.y.isFinite && target.z.isFinite,
            "Screen viewpoint target must be finite."
        )
        precondition(
            pointerOrbitSensitivity.isFinite,
            "Screen viewpoint orbit sensitivity must be finite."
        )
        precondition(
            scrollZoomSensitivity.isFinite,
            "Screen viewpoint zoom sensitivity must be finite."
        )
        precondition(
            minimumRadius.isFinite && minimumRadius > 0,
            "Screen viewpoint minimum radius must be finite and positive."
        )
        precondition(
            maximumRadius.isFinite && maximumRadius >= minimumRadius,
            "Screen viewpoint maximum radius must be finite and no smaller than its minimum."
        )

        self.id = id
        self.target = target
        self.pointerOrbitSensitivity = pointerOrbitSensitivity
        self.scrollZoomSensitivity = scrollZoomSensitivity
        self.minimumRadius = minimumRadius
        self.maximumRadius = maximumRadius
    }

    /// Resolves this screen's immutable viewpoint against the latest default.
    ///
    /// Before the first meaningful presentation gesture, the returned camera
    /// is exactly `defaultCamera`; resolving alone does not create an override
    /// or advance the controller's revision.
    func resolveViewpoint(defaultCamera: Camera) -> RenderViewpoint {
        RenderViewpoint(
            id: id,
            revision: revision,
            camera: overriddenCamera ?? defaultCamera
        )
    }

    /// Applies one presentation-routed host event to the free-orbit viewpoint.
    ///
    /// Horizontal drag and vertical scroll intentionally match the current
    /// `SCameraInput` mapping. Other controls, zero movement, non-finite input,
    /// and movement already stopped by a radius clamp leave the revision alone.
    func receive(_ event: InputEvent, defaultCamera: Camera) {
        switch event {
        case let .mouseDragged(delta, _):
            let yawDelta = delta.x * pointerOrbitSensitivity
            guard yawDelta.isFinite && yawDelta != 0 else {
                return
            }

            let state = currentOrbitState(defaultCamera: defaultCamera)
            let nextYaw = state.yaw + yawDelta
            guard nextYaw.isFinite && nextYaw != state.yaw else {
                return
            }

            publish(
                yaw: nextYaw,
                radius: state.radius,
                verticalTargetOffset: state.verticalTargetOffset,
                projection: state.projection
            )

        case let .scroll(delta):
            let zoomDelta = delta.y * scrollZoomSensitivity
            guard zoomDelta.isFinite && zoomDelta != 0 else {
                return
            }

            let state = currentOrbitState(defaultCamera: defaultCamera)
            let nextRadius = clampedRadius(state.radius - zoomDelta)
            guard nextRadius != state.radius else {
                return
            }

            publish(
                yaw: state.yaw,
                radius: nextRadius,
                verticalTargetOffset: state.verticalTargetOffset,
                projection: state.projection
            )

        case .mouseButtonDown, .mouseButtonUp, .keyDown, .keyUp:
            return
        }
    }

    /// Returns this screen to exact pass-through of its supplied default camera.
    ///
    /// Resetting an already pass-through controller is a no-op. Clearing a real
    /// override is observable and therefore advances the revision once.
    func reset() {
        guard overriddenCamera != nil else {
            return
        }

        overriddenCamera = nil
        yaw = nil
        radius = nil
        verticalTargetOffset = nil
        projection = nil
        revision = revision.advanced()
    }

    private func currentOrbitState(
        defaultCamera: Camera
    ) -> (
        yaw: Float,
        radius: Float,
        verticalTargetOffset: Float,
        projection: Camera.Projection
    ) {
        if let yaw, let radius, let verticalTargetOffset, let projection {
            return (yaw, radius, verticalTargetOffset, projection)
        }

        // Seed horizontal orbit geometry from the latest publisher-authored
        // camera. Its vertical offset remains constant while yaw and radius
        // change, and its projection remains the screen override's projection.
        let offset = defaultCamera.position - target
        let seededRadius = clampedRadius(hypotf(offset.x, offset.z))

        return (
            yaw: atan2f(offset.x, offset.z),
            radius: seededRadius,
            verticalTargetOffset: offset.y,
            projection: defaultCamera.projection
        )
    }

    private func publish(
        yaw: Float,
        radius: Float,
        verticalTargetOffset: Float,
        projection: Camera.Projection
    ) {
        let position = target + SIMD3<Float>(
            sinf(yaw) * radius,
            verticalTargetOffset,
            cosf(yaw) * radius
        )
        let camera = Camera.lookingAt(
            target,
            from: position,
            projection: projection
        )
        guard camera.supportsViewTransform else {
            return
        }

        self.yaw = yaw
        self.radius = radius
        self.verticalTargetOffset = verticalTargetOffset
        self.projection = projection
        overriddenCamera = camera
        revision = revision.advanced()
    }

    private func clampedRadius(_ candidate: Float) -> Float {
        min(maximumRadius, max(minimumRadius, candidate))
    }
}
