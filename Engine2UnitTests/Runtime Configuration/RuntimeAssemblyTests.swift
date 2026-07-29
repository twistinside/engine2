import SwiftUI
import Testing
@testable import Engine2

struct RuntimeAssemblyTests {
    @Test
    func everyProductionAssemblySharesTheAppHostingBoundary() {
        accepts(RealtimeAssembly.self)
        accepts(ManualAssembly.self)
        accepts(OfflineCaptureAssembly.self)
        accepts(AgentSessionAssembly.self)
    }

    @Test
    func nonfallibleAssembliesConstructFromGameContentAsViews() {
        let gameContent = BasicGameContent()

        _ = host(RealtimeAssembly(gameContent: gameContent))
        _ = host(ManualAssembly(gameContent: gameContent))
    }

    @Test
    func protocolConformanceProvidesTheRootViewAndVisibilityLifecycle() throws {
        let recorder = LifecycleRecorder()
        let gameContent = RecordingGameContent(recorder: recorder)
        let assembly = try construct(
            RecordingRuntimeAssembly.self,
            gameContent: gameContent
        )

        _ = assembly.body
        assembly.onAppear()
        assembly.onDisappear()

        #expect(recorder.events == [.appeared, .disappeared])
    }

    @Test
    func genericProtocolConstructionPropagatesFailure() {
        #expect(throws: ConstructionError.expected) {
            _ = try construct(
                ThrowingRuntimeAssembly.self,
                gameContent: BasicGameContent()
            )
        }
    }

    @Test
    func separatelyConstructedAssembliesOwnIndependentSimulationSessions() {
        let gameContent = BasicGameContent()
        let firstRealtime = RealtimeAssembly(gameContent: gameContent)
        let secondRealtime = RealtimeAssembly(gameContent: gameContent)
        let firstManual = ManualAssembly(gameContent: gameContent)
        let secondManual = ManualAssembly(gameContent: gameContent)

        #expect(firstRealtime.simulationRuntime !== secondRealtime.simulationRuntime)
        #expect(
            firstRealtime.simulationRuntime.sessionID !=
            secondRealtime.simulationRuntime.sessionID
        )
        #expect(firstManual.simulationRuntime !== secondManual.simulationRuntime)
        #expect(
            firstManual.simulationRuntime.sessionID !=
            secondManual.simulationRuntime.sessionID
        )
    }

    private func accepts<Assembly: PRuntimeAssembly>(
        _: Assembly.Type
    ) {}

    private func construct<Assembly: PRuntimeAssembly>(
        _: Assembly.Type,
        gameContent: any PGameContent
    ) throws -> Assembly {
        try Assembly(gameContent: gameContent)
    }

    private func host<Assembly: PRuntimeAssembly>(
        _ assembly: Assembly
    ) -> some View {
        assembly
    }

    private enum ConstructionError: Error, Equatable {
        case expected
    }

    private enum LifecycleEvent: Equatable {
        case appeared
        case disappeared
    }

    private final class LifecycleRecorder {
        var events: [LifecycleEvent] = []

        func record(_ event: LifecycleEvent) {
            events.append(event)
        }
    }

    private struct RecordingGameContent: PGameContent {
        let recorder: LifecycleRecorder

        private let base = BasicGameContent()

        var worldBuilder: any PWorldBuilder {
            base.worldBuilder
        }

        var simulationConfiguration: SimulationConfiguration {
            base.simulationConfiguration
        }

        var renderAssetCatalog: RenderAssetCatalog {
            base.renderAssetCatalog
        }
    }

    private struct RecordingRuntimeAssembly: PRuntimeAssembly {
        let recorder: LifecycleRecorder

        var body: some View {
            EmptyView()
        }

        init(gameContent: any PGameContent) throws {
            guard let gameContent = gameContent as? RecordingGameContent else {
                throw ConstructionError.expected
            }
            self.recorder = gameContent.recorder
        }

        func onAppear() {
            recorder.record(.appeared)
        }

        func onDisappear() {
            recorder.record(.disappeared)
        }
    }

    private struct ThrowingRuntimeAssembly: PRuntimeAssembly {
        var body: some View {
            EmptyView()
        }

        init(gameContent: any PGameContent) throws {
            throw ConstructionError.expected
        }
    }
}
