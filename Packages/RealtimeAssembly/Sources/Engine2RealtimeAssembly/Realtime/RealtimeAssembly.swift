import Engine2
import Engine2AssemblySupport
import SwiftUI

/// Owns the live Runtime instances and lifecycle ordering for real-time play.
///
/// One Input Runtime publishes latest input, one cadence driver translates wall
/// time into exact requests, and one Simulation Runtime commits those requests.
/// Its root view wires platform input, screen Render, capture, debug UI, and
/// scene lifecycle without exposing those composition details to the App.
public struct RealtimeAssembly: PRuntimeAssembly, PRealtimeAssemblyViewModel {
    let inputRuntime: InputRuntime
    let simulationRuntime: SimulationRuntime
    let advanceDriver: RealtimeAdvanceDriver
    let renderAssetCatalog: RenderAssetCatalog

    private let lifecycleState: RealtimeAssemblyLifecycleState
    private let snapshotCaptureStore: RealtimeAssemblySnapshotCaptureStore

    /// Root interactive UI and scene-lifecycle adapter presented by the App.
    public var body: some View {
        RealtimeAssemblyView(
            assembly: self,
            snapshotCaptureViewModel: snapshotCaptureStore.viewModel
        )
        .onAppear {
            self.setRootVisible(true)
        }
        .onDisappear {
            self.setRootVisible(false)
        }
    }

    /// Whether user policy currently permits real-time Simulation progress.
    var isAdvancementEnabled: Bool {
        advanceDriver.isAdvancementEnabled
    }

    /// Whether the permitted policy currently has a live cadence task.
    var isAdvancementActive: Bool {
        advanceDriver.isAdvancementEnabled && advanceDriver.isRunning
    }

    /// Latest completed presentation exposed without wider Simulation authority.
    var presentationSource: any PSimulationPresentationSource {
        simulationRuntime
    }

    /// Platform ingress exposed without wider Input Runtime ownership.
    var inputSink: any PInputEventSink {
        inputRuntime
    }

    /// Snapshot of the diagnostics consumed by the current Simulation world.
    var inputHistoryEntries: [InputHistoryEntry] {
        simulationRuntime.inputHistoryEntries
    }

    /// Authority failure requiring an assembly-coordinated cursor transition.
    var advancementFault: RealtimeAdvanceDriverFault? {
        advanceDriver.fault
    }

    /// Constructs a real-time graph with fixed-step polling and interactive catch-up policy.
    public init(gameContent: any PGameContent) {
        self.init(
            gameContent: gameContent,
            pollInterval: SimulationRuntime.fixedTimeStep,
            catchUpPolicy: .interactive
        )
    }

    /// Constructs a real-time graph from explicit content and policy.
    ///
    /// This path preserves deterministic test and specialized-host injection
    /// while keeping graph construction inside the assembly.
    public init(
        gameContent: any PGameContent,
        pollInterval: Duration,
        catchUpPolicy: RealtimeCatchUpPolicy
    ) {
        let inputRuntime = InputRuntime()
        let simulationRuntime = SimulationRuntime(
            worldBuilder: gameContent.worldBuilder,
            configuration: gameContent.simulationConfiguration,
            inputBaseline: inputRuntime.latestInputSnapshot
        )
        let advanceDriver = RealtimeAdvanceDriver(
            advanceTarget: simulationRuntime,
            inputSource: inputRuntime,
            initialCursor: simulationRuntime.currentCursor,
            fixedTimeStep: SimulationRuntime.fixedTimeStep,
            pollInterval: pollInterval,
            catchUpPolicy: catchUpPolicy,
            isAdvancementEnabled: true
        )

        self.inputRuntime = inputRuntime
        self.simulationRuntime = simulationRuntime
        self.advanceDriver = advanceDriver
        self.renderAssetCatalog = gameContent.renderAssetCatalog
        self.lifecycleState = RealtimeAssemblyLifecycleState()
        self.snapshotCaptureStore = RealtimeAssemblySnapshotCaptureStore(
            presentationSource: simulationRuntime,
            renderAssetCatalog: gameContent.renderAssetCatalog
        )
    }

    /// Applies root-view visibility to the real-time lifecycle.
    ///
    /// Hiding the root stops cadence immediately, then drains accepted work before
    /// stopping Input. Transition identity prevents an older hide from stopping
    /// Input after a newer presentation has restarted the assembly.
    func setRootVisible(_ isVisible: Bool) {
        lifecycleState.setRootVisible(isVisible)
        applyVisibilityPolicy()
    }

    /// Applies the scene activity translated by the real-time assembly view.
    func setSceneActive(_ isActive: Bool) {
        lifecycleState.setSceneActive(isActive)
        applyVisibilityPolicy()
    }

    /// Starts the publisher before the cadence connection.
    ///
    /// Starting a fresh driver run makes reactivation an explicit input-connection
    /// boundary. The driver captures that publication immediately, then carries
    /// later active input with it in the first enabled request.
    func start() {
        lifecycleState.beginTransition()
        inputRuntime.start()
        advanceDriver.start()
    }

    /// Stops the cadence connection before its publisher.
    ///
    /// The driver's advancement preference is retained, so scene backgrounding
    /// never turns a deliberate user pause back on.
    func stop() async {
        let transition = beginStop()
        await finishStop(transition: transition)
    }

    /// Reconciles root-view visibility and scene activity without exposing either to peers.
    private func applyVisibilityPolicy() {
        guard lifecycleState.permitsRunning == false else {
            start()
            return
        }

        let transition = beginStop()
        Task {
            await finishStop(transition: transition)
        }
    }

    /// Revokes cadence synchronously so later visibility cannot be stopped by queued work.
    private func beginStop() -> UInt64 {
        let transition = lifecycleState.beginTransition()
        advanceDriver.stop()
        return transition
    }

    /// Drains work accepted before `transition`, then completes that stop if it remains current.
    private func finishStop(transition: UInt64) async {
        await advanceDriver.drainAcceptedWork()

        // A newer start owns lifecycle policy now. Do not let completion of an
        // older asynchronous stop shut down its Input publication session.
        guard lifecycleState.isCurrent(transition) else {
            return
        }

        inputRuntime.stop()
    }

    /// Pauses authoritative progress while Input collection remains live.
    func pauseAdvancement() {
        advanceDriver.pauseAdvancement()
    }

    /// Resumes progress from a captured Input baseline on the next request.
    func resumeAdvancement() {
        advanceDriver.resumeAdvancement()

        // A fault or unexpected clock failure can end cadence independently
        // of the user's desired playback policy. If this assembly is active,
        // resume also restores the task after policy recovery.
        if inputRuntime.isRunning,
           advanceDriver.fault == nil {
            advanceDriver.start()
        }
    }

    /// Applies the one playback toggle exposed to the real-time content view.
    func toggleAdvancement() {
        if isAdvancementActive {
            pauseAdvancement()
        } else {
            resumeAdvancement()
        }
    }

    /// Reconstructs Simulation as one coordinated cursor and input-baseline cutover.
    func rebuildSimulation() async {
        let transition = lifecycleState.beginTransition()
        let wasRunning = advanceDriver.isRunning
        await advanceDriver.stopAndDrain()

        guard lifecycleState.isCurrent(transition) else {
            return
        }

        let inputBaseline = inputRuntime.latestInputSnapshot
        simulationRuntime.rebuildWorld(inputBaseline: inputBaseline)
        advanceDriver.synchronize(
            to: simulationRuntime.currentCursor,
            inputBaseline: inputBaseline
        )

        if wasRunning {
            advanceDriver.start()
        }
    }
}
