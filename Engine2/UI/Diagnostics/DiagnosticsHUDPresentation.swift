/// Compact, immutable values derived from one bounded diagnostics snapshot.
struct DiagnosticsHUDPresentation: Equatable, Sendable {
    let isCollectionEnabled: Bool
    let simulationTick: UInt64?
    let backlogNanoseconds: UInt64
    let renderFreshnessTicks: UInt64?
    let inFlightFrameCount: Int
    let averageRenderCPUNanoseconds: UInt64?
    let maximumRenderCPUNanoseconds: UInt64?
    let latestSystemWorkCount: Int
    let latestError: String?

    init(snapshot: DiagnosticsSnapshot) {
        isCollectionEnabled = snapshot.isCollectionEnabled

        let steps = snapshot.recentSamples.compactMap { sample -> SimulationStepDiagnostics? in
            guard case let .simulationStep(payload) = sample.payload else { return nil }
            return payload
        }
        simulationTick = steps.last?.tick.rawValue

        let polls = snapshot.recentSamples.compactMap { sample -> SimulationPollDiagnostics? in
            guard case let .simulationPoll(payload) = sample.payload else { return nil }
            return payload
        }
        backlogNanoseconds = polls.last?.backlogAfterNanoseconds ?? 0

        let renderFrames = snapshot.recentSamples.compactMap { sample -> RenderFrameCPUDiagnostics? in
            guard case let .renderFrameCPU(payload) = sample.payload else { return nil }
            return payload
        }
        if let simulationTick, let sourceTick = renderFrames.last?.sourceTick?.rawValue {
            renderFreshnessTicks = simulationTick >= sourceTick ? simulationTick - sourceTick : nil
        } else {
            renderFreshnessTicks = nil
        }

        let submittedFrames = Set(
            renderFrames.filter { $0.result == .submitted }.map(\.frameSequence)
        )
        let completedFrames = Set(
            snapshot.recentSamples.compactMap { sample -> RenderFrameSequence? in
                guard case let .gpuFrame(payload) = sample.payload else { return nil }
                return payload.frameSequence
            }
        )
        inFlightFrameCount = submittedFrames.subtracting(completedFrames).count

        if let aggregate = snapshot.aggregates.first(where: { $0.kind == .renderFrameCPU }),
           aggregate.durationSampleCount > 0 {
            averageRenderCPUNanoseconds = aggregate.totalDurationNanoseconds
                / UInt64(aggregate.durationSampleCount)
            maximumRenderCPUNanoseconds = aggregate.maximumDurationNanoseconds
        } else {
            averageRenderCPUNanoseconds = nil
            maximumRenderCPUNanoseconds = nil
        }

        let systemUpdates = snapshot.recentSamples.compactMap { sample -> SystemUpdateDiagnostics? in
            guard case let .systemUpdate(payload) = sample.payload else { return nil }
            return payload
        }
        let latestSystemTick = systemUpdates.last?.tick
        latestSystemWorkCount = systemUpdates
            .filter { $0.tick == latestSystemTick }
            .compactMap(\.workCount)
            .reduce(0, +)

        latestError = snapshot.recentSamples.reversed().compactMap { sample -> String? in
            switch sample.payload {
            case let .gpuFrame(payload) where payload.result == .failed:
                payload.errorType ?? "GPU feedback failed"
            case let .renderResourceFailure(payload):
                "\(payload.stage.rawValue): \(payload.errorType)"
            default:
                nil
            }
        }.first
    }
}

#if DEBUG
extension DiagnosticsHUDPresentation {
    /// Stable healthy-state fixture shared by previews during UI iteration.
    static let preview = DiagnosticsHUDPresentation(
        snapshot: DiagnosticsSnapshot(
            sessionID: DiagnosticsSessionID(),
            isCollectionEnabled: true,
            recentSampleCapacity: 32,
            totalSamplesReceived: 1,
            recentSamples: [
                DiagnosticsSample(
                    sessionID: DiagnosticsSessionID(),
                    timestamp: .zero,
                    category: .simulationLoop,
                    payload: .simulationStep(
                        SimulationStepDiagnostics(
                            tick: SimulationTick(rawValue: 240),
                            didRunSimulationSystems: true,
                            durationNanoseconds: 120_000
                        )
                    )
                )
            ],
            aggregates: []
        )
    )
}
#endif
