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
    func nonfallibleAssembliesSelfConstructAsViews() {
        _ = host(RealtimeAssembly())
        _ = host(ManualAssembly())
    }

    @Test
    func protocolConformanceProvidesTheRootView() {
        let assembly = RealtimeAssembly()

        _ = assembly.body
    }

    @Test
    func genericProtocolConstructionPropagatesFailure() {
        ThrowingRuntimeAssembly.attemptCount = 0

        #expect(throws: ConstructionError.expected) {
            _ = try construct(ThrowingRuntimeAssembly.self)
        }

        #expect(ThrowingRuntimeAssembly.attemptCount == 1)
    }

    @Test
    func selfConstructedAssembliesOwnIndependentSimulationSessions() {
        let firstRealtime = RealtimeAssembly()
        let secondRealtime = RealtimeAssembly()
        let firstManual = ManualAssembly()
        let secondManual = ManualAssembly()

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
        _: Assembly.Type
    ) throws -> Assembly {
        try Assembly()
    }

    private func host<Assembly: PRuntimeAssembly>(
        _ assembly: Assembly
    ) -> some View {
        assembly
    }

    private enum ConstructionError: Error, Equatable {
        case expected
    }

    private struct ThrowingRuntimeAssembly: PRuntimeAssembly {
        static var attemptCount = 0

        var body: some View {
            EmptyView()
        }

        init() throws {
            Self.attemptCount += 1
            throw ConstructionError.expected
        }
    }
}
