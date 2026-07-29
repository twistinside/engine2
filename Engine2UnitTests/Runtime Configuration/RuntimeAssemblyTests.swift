import SwiftUI
import Testing
@testable import Engine2
@testable import BasicGameContent
@testable import Engine2AgentSessionAssembly
@testable import Engine2AssemblySupport
@testable import Engine2ManualAssembly
@testable import Engine2OfflineCaptureAssembly
@testable import Engine2RealtimeAssembly

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
    func protocolConformanceProvidesInjectedConstructionAndRootView() throws {
        let assembly = try construct(
            MinimalRuntimeAssembly.self,
            gameContent: BasicGameContent()
        )

        _ = host(assembly)
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

    private struct MinimalRuntimeAssembly: PRuntimeAssembly {
        var body: some View {
            EmptyView()
        }

        init(gameContent _: any PGameContent) throws {}
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
