import Foundation
import OSLog

/// Emits stable Apple-system instrumentation and forwards compact typed samples.
///
/// Runtime owners call domain-specific methods so signpost names, public-field
/// policy, and sample construction stay centralized. The optional sink remains
/// the machine-readable source; unified logs and signposts are observational.
final class DiagnosticsEmitter {
    typealias TimeSource = () -> SuspendingClock.Instant

    let sessionID: DiagnosticsSessionID

    private let sessionStart: SuspendingClock.Instant
    private weak var sink: (any PDiagnosticsSink)?
    private let timeSource: TimeSource

    init(
        sessionID: DiagnosticsSessionID = DiagnosticsSessionID(),
        sink: any PDiagnosticsSink = NoOpDiagnosticsSink(),
        timeSource: @escaping TimeSource = { SuspendingClock().now }
    ) {
        self.sessionID = sessionID
        self.sink = sink
        self.timeSource = timeSource
        self.sessionStart = timeSource()
    }

    /// Measures and reports one completed fixed step without changing its result.
    func measureSimulationStep<Result>(
        tick: SimulationTick,
        didRunSimulationSystems: Bool,
        operation: () throws -> Result
    ) rethrows -> Result {
        let start = timeSource()
        defer {
            let end = timeSource()
            record(
                category: .simulationLoop,
                timestampAt: end,
                payload: .simulationStep(
                    SimulationStepDiagnostics(
                        tick: tick,
                        didRunSimulationSystems: didRunSimulationSystems,
                        durationNanoseconds: start.duration(to: end).diagnosticsNanoseconds
                    )
                )
            )
        }

        let signposter = DiagnosticsOSHandles.signposter(for: .simulationLoop)
        guard signposter.isEnabled else {
            return try operation()
        }

        let signpostID = signposter.makeSignpostID()
        return try signposter.withIntervalSignpost(
            "SimulationStep",
            id: signpostID,
            "session=\(self.sessionID.rawValue.uuidString, privacy: .public) tick=\(tick.rawValue, privacy: .public) simulation=\(didRunSimulationSystems, privacy: .public)",
            around: operation
        )
    }

    /// Captures and reports the Simulation-owned presentation boundary once.
    func capturePresentationSnapshot(
        from world: World,
        at tick: SimulationTick
    ) -> SimulationPresentationSnapshot {
        let start = timeSource()
        let renderableRowCount = world.renderableComponents.dense.count
        let signposter = DiagnosticsOSHandles.signposter(for: .simulationSnapshot)
        let snapshot: SimulationPresentationSnapshot

        if signposter.isEnabled {
            let signpostID = signposter.makeSignpostID()
            snapshot = signposter.withIntervalSignpost(
                "PresentationSnapshotCapture",
                id: signpostID,
                "session=\(self.sessionID.rawValue.uuidString, privacy: .public) tick=\(tick.rawValue, privacy: .public) renderable_rows=\(renderableRowCount, privacy: .public)"
            ) {
                SimulationPresentationSnapshot.capture(from: world, at: tick)
            }
        } else {
            snapshot = SimulationPresentationSnapshot.capture(from: world, at: tick)
        }

        let end = timeSource()
        record(
            category: .simulationSnapshot,
            timestampAt: end,
            payload: .presentationSnapshot(
                PresentationSnapshotDiagnostics(
                    tick: tick,
                    renderableRowCount: renderableRowCount,
                    publishedPresentationCount: snapshot.entityPresentations.count,
                    durationNanoseconds: start.duration(to: end).diagnosticsNanoseconds
                )
            )
        )
        return snapshot
    }

    /// Measures the Render-owned projection without reading Simulation internals.
    func measureRenderProjection(
        from snapshot: SimulationPresentationSnapshot
    ) -> RenderFrame {
        let start = timeSource()
        let signposter = DiagnosticsOSHandles.signposter(for: .renderFrame)
        let frame: RenderFrame
        if signposter.isEnabled {
            let signpostID = signposter.makeSignpostID()
            frame = signposter.withIntervalSignpost(
                "RenderProjection",
                id: signpostID,
                "session=\(self.sessionID.rawValue.uuidString, privacy: .public) tick=\(snapshot.tick.rawValue, privacy: .public) published=\(snapshot.entityPresentations.count, privacy: .public)"
            ) {
                RenderFrame.project(from: snapshot)
            }
        } else {
            frame = RenderFrame.project(from: snapshot)
        }

        let end = timeSource()
        record(
            category: .renderFrame,
            timestampAt: end,
            payload: .renderProjection(
                RenderProjectionDiagnostics(
                    sourceTick: snapshot.tick,
                    publishedPresentationCount: snapshot.entityPresentations.count,
                    acceptedInstanceCount: frame.instances.count,
                    rejectedPresentationCount: snapshot.entityPresentations.count - frame.instances.count,
                    durationNanoseconds: start.duration(to: end).diagnosticsNanoseconds
                )
            )
        )
        return frame
    }

    /// Measures main-actor back pressure at the bounded frame ring.
    func measureFrameSlotWait(
        frameSequence: RenderFrameSequence,
        frameSlot: Int,
        operation: () -> Void
    ) {
        let start = timeSource()
        let signposter = DiagnosticsOSHandles.signposter(for: .renderFrame)
        if signposter.isEnabled {
            signposter.withIntervalSignpost(
                "FrameSlotWait",
                id: signposter.makeSignpostID(),
                "session=\(self.sessionID.rawValue.uuidString, privacy: .public) frame=\(frameSequence.rawValue, privacy: .public) slot=\(frameSlot, privacy: .public)",
                around: operation
            )
        } else {
            operation()
        }
        let end = timeSource()
        record(
            category: .renderFrame,
            timestampAt: end,
            payload: .frameSlotWait(
                FrameSlotWaitDiagnostics(
                    frameSequence: frameSequence,
                    frameSlot: frameSlot,
                    durationNanoseconds: start.duration(to: end).diagnosticsNanoseconds
                )
            )
        )
    }

    /// Begins Render encoding without moving Metal objects across a closure boundary.
    func beginFrameEncode(
        frameSequence: RenderFrameSequence,
        sourceTick: SimulationTick
    ) -> FrameEncodeMeasurement {
        let start = timeSource()
        let signposter = DiagnosticsOSHandles.signposter(for: .renderFrame)
        let state = signposter.beginInterval(
            "FrameEncode",
            id: signposter.makeSignpostID(),
            "session=\(self.sessionID.rawValue.uuidString, privacy: .public) frame=\(frameSequence.rawValue, privacy: .public) tick=\(sourceTick.rawValue, privacy: .public)"
        )
        return FrameEncodeMeasurement(start: start, signpostState: state)
    }

    /// Ends Render encoding and reports counts from its real traversal.
    func endFrameEncode(
        _ measurement: FrameEncodeMeasurement,
        frameSequence: RenderFrameSequence,
        sourceTick: SimulationTick,
        counts: RenderDrawCounts
    ) {
        let end = timeSource()
        DiagnosticsOSHandles.signposter(for: .renderFrame).endInterval(
            "FrameEncode",
            measurement.signpostState
        )
        record(
            category: .renderFrame,
            timestampAt: end,
            payload: .frameEncode(
                FrameEncodeDiagnostics(
                    frameSequence: frameSequence,
                    sourceTick: sourceTick,
                    renderPassCount: 2,
                    drawCount: counts.drawCount,
                    submeshCount: counts.submeshCount,
                    durationNanoseconds: measurement.start.duration(to: end).diagnosticsNanoseconds
                )
            )
        )
    }

    /// Measures the complete CPU callback and records its explicit outcome.
    func measureRenderFrameCPU(
        frameSequence: RenderFrameSequence,
        operation: () -> RenderFrameCPUDiagnostics
    ) {
        let start = timeSource()
        let signposter = DiagnosticsOSHandles.signposter(for: .renderFrame)
        var outcome: RenderFrameCPUDiagnostics
        if signposter.isEnabled {
            outcome = signposter.withIntervalSignpost(
                "RenderFrameCPU",
                id: signposter.makeSignpostID(),
                "session=\(self.sessionID.rawValue.uuidString, privacy: .public) frame=\(frameSequence.rawValue, privacy: .public)",
                around: operation
            )
        } else {
            outcome = operation()
        }
        let end = timeSource()
        outcome.durationNanoseconds = start.duration(to: end).diagnosticsNanoseconds
        record(
            category: .renderFrame,
            timestampAt: end,
            payload: .renderFrameCPU(outcome)
        )
    }

    /// Measures eager pipeline construction while preserving cache behavior.
    func measurePipelineCompile<Result>(
        pipelineID: MetalRenderPipelineID,
        wasCacheHit: Bool,
        operation: @escaping () throws -> Result
    ) throws -> Result {
        let start = timeSource()
        var succeeded = false
        defer {
            let end = timeSource()
            record(
                category: .renderAsset,
                timestampAt: end,
                payload: .pipelineCompile(
                    PipelineCompileDiagnostics(
                        pipelineID: pipelineID,
                        wasCacheHit: wasCacheHit,
                        succeeded: succeeded,
                        durationNanoseconds: start.duration(to: end).diagnosticsNanoseconds
                    )
                )
            )
        }

        let operationWithSuccess = {
            let result = try operation()
            succeeded = true
            return result
        }
        let signposter = DiagnosticsOSHandles.signposter(for: .renderAsset)
        guard signposter.isEnabled else {
            return try operationWithSuccess()
        }
        return try signposter.withIntervalSignpost(
            "PipelineCompile",
            id: signposter.makeSignpostID(),
            "session=\(self.sessionID.rawValue.uuidString, privacy: .public) pipeline=\(pipelineID.rawValue, privacy: .public) cache_hit=\(wasCacheHit, privacy: .public)",
            around: operationWithSuccess
        )
    }

    /// Measures model decoding and reports backend structure after success.
    func measureAssetLoad(
        requestedModelCount: Int,
        operation: @escaping () throws -> RenderAssetLoadCounts
    ) throws -> RenderAssetLoadCounts {
        let start = timeSource()
        var outcome = RenderAssetLoadCounts(
            loadedModelCount: 0,
            meshCount: 0,
            submeshCount: 0
        )
        var succeeded = false
        defer {
            let end = timeSource()
            record(
                category: .renderAsset,
                timestampAt: end,
                payload: .assetLoad(
                    AssetLoadDiagnostics(
                        requestedModelCount: requestedModelCount,
                        loadedModelCount: outcome.loadedModelCount,
                        meshCount: outcome.meshCount,
                        submeshCount: outcome.submeshCount,
                        succeeded: succeeded,
                        durationNanoseconds: start.duration(to: end).diagnosticsNanoseconds
                    )
                )
            )
        }

        let operationWithSuccess = {
            outcome = try operation()
            succeeded = true
            return outcome
        }
        let signposter = DiagnosticsOSHandles.signposter(for: .renderAsset)
        guard signposter.isEnabled else {
            return try operationWithSuccess()
        }
        return try signposter.withIntervalSignpost(
            "AssetLoad",
            id: signposter.makeSignpostID(),
            "session=\(self.sessionID.rawValue.uuidString, privacy: .public) requested_models=\(requestedModelCount, privacy: .public)",
            around: operationWithSuccess
        )
    }

    /// Records completed device-scoped resource structure once per store.
    func recordRenderResourceInventory(_ inventory: RenderResourceInventoryDiagnostics) {
        record(category: .renderAsset, payload: .renderResourceInventory(inventory))
    }

    /// Logs a preserved construction failure without changing throw behavior.
    func logRenderPreparationFailed(
        stage: RenderResourceConstructionStage,
        error: any Error
    ) {
        let errorType = String(reflecting: type(of: error))
        DiagnosticsOSHandles.logger(for: .renderAsset).error(
            "event=render_preparation_failed session=\(self.sessionID.rawValue.uuidString, privacy: .public) stage=\(stage.rawValue, privacy: .public) error_type=\(errorType, privacy: .public)"
        )
        record(
            category: .renderAsset,
            payload: .renderResourceFailure(
                RenderResourceFailureDiagnostics(
                    stage: stage,
                    errorType: errorType
                )
            )
        )
    }

    /// Begins a GPU interval that remains valid through asynchronous feedback.
    func beginGPUFrame(
        submissionID: RenderSubmissionID,
        frameSequence: RenderFrameSequence,
        sourceTick: SimulationTick,
        frameSlot: Int
    ) -> GPUFrameCompletion {
        let start = timeSource()
        let signposter = DiagnosticsOSHandles.signposter(for: .renderGPU)
        let state = signposter.beginInterval(
            "GPUFrame",
            id: signposter.makeSignpostID(),
            "session=\(self.sessionID.rawValue.uuidString, privacy: .public) submission=\(submissionID.rawValue, privacy: .public) frame=\(frameSequence.rawValue, privacy: .public) tick=\(sourceTick.rawValue, privacy: .public) slot=\(frameSlot, privacy: .public)"
        )
        return GPUFrameCompletion(
            emitter: self,
            measurement: GPUFrameDiagnostics(
                submissionID: submissionID,
                frameSequence: frameSequence,
                sourceTick: sourceTick,
                frameSlot: frameSlot,
                result: .notSubmitted,
                errorType: nil,
                durationNanoseconds: 0
            ),
            sessionStart: sessionStart,
            start: start,
            signpostState: state
        )
    }

    /// Retains completed GPU feedback using its exact completion timestamp.
    func recordCompletedGPUFrame(
        _ measurement: GPUFrameDiagnostics,
        timestamp: DiagnosticsTimestamp
    ) {
        if measurement.result == .failed {
            DiagnosticsOSHandles.logger(for: .renderGPU).error(
                "event=render_submission_failed session=\(self.sessionID.rawValue.uuidString, privacy: .public) submission=\(measurement.submissionID.rawValue, privacy: .public) frame=\(measurement.frameSequence.rawValue, privacy: .public)"
            )
        }
        sink?.record(
            DiagnosticsSample(
                sessionID: sessionID,
                timestamp: timestamp,
                category: .renderGPU,
                payload: .gpuFrame(measurement)
            )
        )
    }

    /// Measures one app-loop poll and records its fixed-step/backlog outcome.
    func measureSimulationPoll(
        sampledWallDelta: Duration,
        backlogBefore: Duration,
        operation: () -> Void,
        outcome: () -> (completedTick: SimulationTick, stepsCompleted: Int, backlogAfter: Duration)
    ) {
        let start = timeSource()
        let signposter = DiagnosticsOSHandles.signposter(for: .simulationLoop)

        if signposter.isEnabled {
            let signpostID = signposter.makeSignpostID()
            signposter.withIntervalSignpost(
                "SimulationPoll",
                id: signpostID,
                "session=\(self.sessionID.rawValue.uuidString, privacy: .public) wall_delta_ns=\(sampledWallDelta.diagnosticsNanoseconds, privacy: .public) backlog_before_ns=\(backlogBefore.diagnosticsNanoseconds, privacy: .public)",
                around: operation
            )
        } else {
            operation()
        }

        let result = outcome()
        let end = timeSource()
        record(
            category: .simulationLoop,
            timestampAt: end,
            payload: .simulationPoll(
                SimulationPollDiagnostics(
                    completedTick: result.completedTick,
                    sampledWallDeltaNanoseconds: sampledWallDelta.diagnosticsNanoseconds,
                    stepsCompleted: result.stepsCompleted,
                    backlogBeforeNanoseconds: backlogBefore.diagnosticsNanoseconds,
                    backlogAfterNanoseconds: result.backlogAfter.diagnosticsNanoseconds,
                    durationNanoseconds: start.duration(to: end).diagnosticsNanoseconds
                )
            )
        )
    }

    /// Records the start of an app-owned Simulation Runtime polling session.
    func logSimulationLoopStarted(pollInterval: Duration) {
        DiagnosticsOSHandles.logger(for: .simulationLoop).info(
            "event=simulation_loop_started session=\(self.sessionID.rawValue.uuidString, privacy: .public) poll_interval_ns=\(pollInterval.diagnosticsNanoseconds, privacy: .public)"
        )
    }

    /// Records an explicit owner-requested stop of the polling session.
    func logSimulationLoopStopped(completedTick: SimulationTick) {
        DiagnosticsOSHandles.logger(for: .simulationLoop).info(
            "event=simulation_loop_stopped session=\(self.sessionID.rawValue.uuidString, privacy: .public) tick=\(completedTick.rawValue, privacy: .public)"
        )
    }

    /// Records cancellation separately from the owner's stop request.
    func logSimulationLoopCancelled(completedTick: SimulationTick) {
        DiagnosticsOSHandles.logger(for: .simulationLoop).debug(
            "event=simulation_loop_cancelled session=\(self.sessionID.rawValue.uuidString, privacy: .public) tick=\(completedTick.rawValue, privacy: .public)"
        )
    }

    /// Records a handled catch-up threshold crossing without changing policy.
    func logSimulationBacklogHigh(
        completedTick: SimulationTick,
        stepsCompleted: Int,
        availableBacklog: Duration
    ) {
        DiagnosticsOSHandles.logger(for: .simulationLoop).notice(
            "event=simulation_backlog_high session=\(self.sessionID.rawValue.uuidString, privacy: .public) tick=\(completedTick.rawValue, privacy: .public) steps=\(stepsCompleted, privacy: .public) backlog_ns=\(availableBacklog.diagnosticsNanoseconds, privacy: .public)"
        )
    }

    /// Measures and reports one invariant system update in schedule order.
    func measureSystemUpdate<Result>(
        tick: SimulationTick,
        systemID: SimulationSystemID,
        scheduleLane: SimulationScheduleLane,
        executionOrder: Int,
        workCount: Int? = nil,
        operation: () throws -> Result
    ) rethrows -> Result {
        let start = timeSource()
        defer {
            let end = timeSource()
            record(
                category: .simulationSystem,
                timestampAt: end,
                payload: .systemUpdate(
                    SystemUpdateDiagnostics(
                        tick: tick,
                        systemID: systemID,
                        scheduleLane: scheduleLane,
                        executionOrder: executionOrder,
                        durationNanoseconds: start.duration(to: end).diagnosticsNanoseconds,
                        workCount: workCount
                    )
                )
            )
        }

        let signposter = DiagnosticsOSHandles.signposter(for: .simulationSystem)
        guard signposter.isEnabled else {
            return try operation()
        }

        let signpostID = signposter.makeSignpostID()
        return try signposter.withIntervalSignpost(
            "SystemUpdate",
            id: signpostID,
            "session=\(self.sessionID.rawValue.uuidString, privacy: .public) tick=\(tick.rawValue, privacy: .public) system=\(systemID.rawValue, privacy: .public) lane=\(scheduleLane.rawValue, privacy: .public) order=\(executionOrder, privacy: .public)",
            around: operation
        )
    }

    /// Forwards an already-typed fact without requiring a system-log assertion.
    func record(
        category: DiagnosticsCategory,
        payload: DiagnosticsSamplePayload
    ) {
        record(category: category, timestampAt: timeSource(), payload: payload)
    }

    /// Records low-frequency structural complexity at world construction.
    func recordSimulationRuntimeInventory(
        alwaysSystemIDs: [SimulationSystemID],
        simulationSystemIDs: [SimulationSystemID],
        componentStores: [ComponentStoreInventory],
        presentationEntityCount: Int
    ) {
        record(
            category: .simulationLoop,
            payload: .simulationRuntimeInventory(
                SimulationRuntimeInventoryDiagnostics(
                    alwaysSystemIDs: alwaysSystemIDs,
                    simulationSystemIDs: simulationSystemIDs,
                    componentStores: componentStores,
                    presentationEntityCount: presentationEntityCount
                )
            )
        )
    }

    /// Emits one sampled host-event ingress point with no input content.
    func emitInputReceive(
        eventID: InputEventDiagnosticsID,
        revision: InputRevision
    ) {
        let signposter = DiagnosticsOSHandles.signposter(for: .inputRuntime)
        if signposter.isEnabled {
            signposter.emitEvent(
                "InputReceive",
                "session=\(self.sessionID.rawValue.uuidString, privacy: .public) input_session=\(revision.session, privacy: .public) revision=\(revision.sequence, privacy: .public) kind=\(eventID.rawValue, privacy: .public)"
            )
        }
        record(
            category: .inputRuntime,
            payload: .inputReceive(
                InputReceiveDiagnostics(eventID: eventID, revision: revision)
            )
        )
    }

    /// Emits one immutable input-publication point using held-state counts only.
    func emitInputSnapshot(
        revision: InputRevision,
        heldKeyCount: Int,
        heldMouseButtonCount: Int
    ) {
        let signposter = DiagnosticsOSHandles.signposter(for: .inputRuntime)
        if signposter.isEnabled {
            signposter.emitEvent(
                "InputSnapshotPublish",
                "session=\(self.sessionID.rawValue.uuidString, privacy: .public) input_session=\(revision.session, privacy: .public) revision=\(revision.sequence, privacy: .public) held_keys=\(heldKeyCount, privacy: .public) held_buttons=\(heldMouseButtonCount, privacy: .public)"
            )
        }
        record(
            category: .inputRuntime,
            payload: .inputSnapshot(
                InputSnapshotDiagnostics(
                    revision: revision,
                    heldKeyCount: heldKeyCount,
                    heldMouseButtonCount: heldMouseButtonCount
                )
            )
        )
    }

    private func record(
        category: DiagnosticsCategory,
        timestampAt instant: SuspendingClock.Instant,
        payload: DiagnosticsSamplePayload
    ) {
        sink?.record(
            DiagnosticsSample(
                sessionID: sessionID,
                timestamp: DiagnosticsTimestamp(
                    nanosecondsSinceSessionStart: sessionStart
                        .duration(to: instant)
                        .diagnosticsNanoseconds
                ),
                category: category,
                payload: payload
            )
        )
    }
}
