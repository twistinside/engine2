import SwiftUI
import Testing
@testable import Engine2

struct RuntimeAssemblyTests {
    @Test
    func realtimeAssemblyUsesTheAppHostingBoundary() {
        accepts(RealtimeAssembly.self)
    }

    @Test
    func realtimeAssemblyConstructsFromGameContentAsAView() {
        let content = BasicGameContent()

        _ = host(RealtimeAssembly(using: content))
    }

    @Test
    func protocolConformanceProvidesInjectedConstructionAndRootView() {
        let assembly = construct(
            MinimalRuntimeAssembly.self,
            gameContent: BasicGameContent()
        )

        _ = host(assembly)
    }

    @Test
    func separatelyConstructedAssembliesOwnIndependentSimulationSessions() {
        let content = BasicGameContent()
        let firstRealtime = RealtimeAssembly(using: content)
        let secondRealtime = RealtimeAssembly(using: content)

        #expect(firstRealtime.simulationRuntime !== secondRealtime.simulationRuntime)
        #expect(
            firstRealtime.simulationRuntime.currentCursor.sessionID !=
            secondRealtime.simulationRuntime.currentCursor.sessionID
        )
    }

    private func accepts<Assembly: RuntimeAssembly>(
        _: Assembly.Type
    ) {}

    private func construct<Assembly: RuntimeAssembly>(
        _: Assembly.Type,
        gameContent: any GameContent
    ) -> Assembly {
        Assembly(using: gameContent)
    }

    private func host<Assembly: RuntimeAssembly>(
        _ assembly: Assembly
    ) -> some View {
        assembly
    }

    private struct MinimalRuntimeAssembly: RuntimeAssembly {
        var body: some View {
            EmptyView()
        }

        init(using _: any GameContent) {}
    }
}
