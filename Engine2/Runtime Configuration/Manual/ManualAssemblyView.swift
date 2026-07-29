import SwiftUI

/// Presents caller-driven Simulation without inventing an Input Runtime or cadence.
struct ManualAssemblyView: View {
    let assembly: ManualAssembly

    @State private var currentCursor: SimulationCursor
    @State private var isAdvancing = false
    @State private var advanceTask: Task<Void, Never>?
    @State private var outputMode = RenderOutputMode.surface

    var body: some View {
        ZStack {
            MetalSceneView(
                renderAssetCatalog: assembly.renderAssetCatalog,
                presentationSource: assembly.presentationSource,
                inputSink: nil,
                outputMode: outputMode
            )
            .ignoresSafeArea()

            ManualSimulationControls(
                currentCursor: currentCursor,
                isAdvancing: isAdvancing,
                advanceOneTick: advanceOneTick
            )
        }
        .toolbar {
            ManualAssemblyToolbar(outputMode: $outputMode)
        }
        .onAppear {
            currentCursor = assembly.presentationSource.latestPresentationSnapshot.cursor
        }
        .onDisappear {
            advanceTask?.cancel()
            advanceTask = nil
        }
    }

    init(assembly: ManualAssembly) {
        self.assembly = assembly
        _currentCursor = State(
            initialValue: assembly.presentationSource.latestPresentationSnapshot.cursor
        )
    }

    private func advanceOneTick() {
        guard advanceTask == nil else {
            return
        }

        isAdvancing = true
        currentCursor = assembly.presentationSource.latestPresentationSnapshot.cursor
        let request = SimulationAdvanceRequest(
            expectedCursor: currentCursor,
            stepCount: .one,
            inputAssignment: .none
        )

        advanceTask = Task {
            let outcome = await assembly.advanceTarget.advance(request)

            switch outcome {
            case let .completed(result):
                currentCursor = result.finalCursor
            case let .rejected(.cursorMismatch(_, current)):
                currentCursor = current
            }

            isAdvancing = false
            advanceTask = nil
        }
    }
}

#Preview {
    ManualAssembly(gameContent: BasicGameContent())
        .frame(width: 960, height: 640)
}
