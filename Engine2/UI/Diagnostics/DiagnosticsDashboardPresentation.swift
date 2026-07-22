/// Read-only chart and table inputs derived entirely from a bounded snapshot.
struct DiagnosticsDashboardPresentation: Equatable, Sendable {
    let cadence: [DiagnosticsMetricPoint]
    let systemDurations: [DiagnosticsMetricPoint]
    let backlog: [DiagnosticsMetricPoint]
    let freshness: [DiagnosticsMetricPoint]
    let presentationFunnel: [DiagnosticsNamedCount]
    let renderPhases: [DiagnosticsMetricPoint]
    let resources: [DiagnosticsNamedCount]
    let errors: [DiagnosticsErrorPresentation]

    init(snapshot: DiagnosticsSnapshot) {
        var cadence: [DiagnosticsMetricPoint] = []
        var systemDurations: [DiagnosticsMetricPoint] = []
        var backlog: [DiagnosticsMetricPoint] = []
        var freshness: [DiagnosticsMetricPoint] = []
        var renderPhases: [DiagnosticsMetricPoint] = []
        var errors: [DiagnosticsErrorPresentation] = []
        var latestSimulationTick: UInt64?
        var latestProjection: RenderProjectionDiagnostics?
        var latestRenderFrame: RenderFrameCPUDiagnostics?
        var simulationInventory: SimulationRuntimeInventoryDiagnostics?
        var renderInventory: RenderResourceInventoryDiagnostics?

        for (index, sample) in snapshot.recentSamples.enumerated() {
            let timestamp = sample.timestamp.nanosecondsSinceSessionStart
            switch sample.payload {
            case let .simulationStep(payload):
                latestSimulationTick = payload.tick.rawValue
                cadence.append(Self.point(index, .simulationStep, timestamp, payload.durationNanoseconds))
            case let .presentationSnapshot(payload):
                cadence.append(Self.point(index, .presentationSnapshot, timestamp, payload.durationNanoseconds))
            case let .renderProjection(payload):
                latestProjection = payload
                cadence.append(Self.point(index, .renderProjection, timestamp, payload.durationNanoseconds))
                renderPhases.append(Self.point(index, .renderProjection, timestamp, payload.durationNanoseconds))
            case let .frameSlotWait(payload):
                renderPhases.append(Self.point(index, .frameSlotWait, timestamp, payload.durationNanoseconds))
            case let .frameEncode(payload):
                renderPhases.append(Self.point(index, .frameEncode, timestamp, payload.durationNanoseconds))
            case let .renderFrameCPU(payload):
                latestRenderFrame = payload
                cadence.append(Self.point(index, .renderFrameCPU, timestamp, payload.durationNanoseconds))
                renderPhases.append(Self.point(index, .renderFrameCPU, timestamp, payload.durationNanoseconds))
                if let latestSimulationTick, let sourceTick = payload.sourceTick?.rawValue,
                   latestSimulationTick >= sourceTick {
                    freshness.append(
                        DiagnosticsMetricPoint(
                            id: index,
                            series: .freshness,
                            x: timestamp,
                            value: Double(latestSimulationTick - sourceTick),
                            label: "frame \(payload.frameSequence.rawValue)"
                        )
                    )
                }
            case let .gpuFrame(payload):
                cadence.append(Self.point(index, .gpuFrame, timestamp, payload.durationNanoseconds))
                renderPhases.append(Self.point(index, .gpuFrame, timestamp, payload.durationNanoseconds))
                if payload.result == .failed {
                    errors.append(
                        DiagnosticsErrorPresentation(
                            id: index,
                            timestampNanoseconds: timestamp,
                            source: "GPU submission \(payload.submissionID.rawValue)",
                            detail: payload.errorType ?? "feedback failed"
                        )
                    )
                }
            case let .simulationPoll(payload):
                backlog.append(
                    DiagnosticsMetricPoint(
                        id: index,
                        series: .backlog,
                        x: timestamp,
                        value: Double(payload.backlogAfterNanoseconds),
                        label: "tick \(payload.completedTick.rawValue)"
                    )
                )
            case let .systemUpdate(payload):
                systemDurations.append(
                    DiagnosticsMetricPoint(
                        id: index,
                        series: .system,
                        x: payload.tick.rawValue,
                        value: Double(payload.durationNanoseconds),
                        label: payload.systemID.rawValue
                    )
                )
            case let .simulationRuntimeInventory(payload):
                simulationInventory = payload
            case let .renderResourceInventory(payload):
                renderInventory = payload
            case let .renderResourceFailure(payload):
                errors.append(
                    DiagnosticsErrorPresentation(
                        id: index,
                        timestampNanoseconds: timestamp,
                        source: payload.stage.rawValue,
                        detail: payload.errorType
                    )
                )
            default:
                break
            }
        }

        self.cadence = cadence
        self.systemDurations = systemDurations
        self.backlog = backlog
        self.freshness = freshness
        self.renderPhases = renderPhases
        self.presentationFunnel = [
            DiagnosticsNamedCount(
                name: "Published",
                count: latestProjection?.publishedPresentationCount ?? 0
            ),
            DiagnosticsNamedCount(
                name: "Accepted",
                count: latestProjection?.acceptedInstanceCount ?? 0
            ),
            DiagnosticsNamedCount(
                name: "Rejected",
                count: latestProjection?.rejectedPresentationCount ?? 0
            ),
            DiagnosticsNamedCount(
                name: "Submitted",
                count: latestRenderFrame?.submittedInstanceCount ?? 0
            )
        ]

        var resources: [DiagnosticsNamedCount] = simulationInventory?.componentStores.map {
            DiagnosticsNamedCount(name: $0.storeID.rawValue, count: $0.rowCount)
        } ?? []
        if let renderInventory {
            resources.append(contentsOf: [
                DiagnosticsNamedCount(name: "models", count: renderInventory.modelCount),
                DiagnosticsNamedCount(name: "meshes", count: renderInventory.meshCount),
                DiagnosticsNamedCount(name: "submeshes", count: renderInventory.submeshCount),
                DiagnosticsNamedCount(name: "pipelines", count: renderInventory.pipelineCount),
                DiagnosticsNamedCount(name: "argument tables", count: renderInventory.argumentTableCount),
                DiagnosticsNamedCount(name: "materials", count: renderInventory.materialCount),
                DiagnosticsNamedCount(name: "frame resources", count: renderInventory.frameResourceCount)
            ])
        }
        self.resources = resources
        self.errors = errors
    }

    private static func point(
        _ id: Int,
        _ series: DiagnosticsMetricSeries,
        _ timestamp: UInt64,
        _ value: UInt64
    ) -> DiagnosticsMetricPoint {
        DiagnosticsMetricPoint(
            id: id,
            series: series,
            x: timestamp,
            value: Double(value),
            label: series.rawValue
        )
    }
}

#if DEBUG
extension DiagnosticsDashboardPresentation {
    static func preview(_ state: DiagnosticsDashboardPreviewState) -> DiagnosticsDashboardPresentation {
        let sessionID = DiagnosticsSessionID()
        var samples: [DiagnosticsSample] = []
        func append(_ payload: DiagnosticsSamplePayload) {
            samples.append(
                DiagnosticsSample(
                    sessionID: sessionID,
                    timestamp: DiagnosticsTimestamp(
                        nanosecondsSinceSessionStart: UInt64(samples.count + 1) * 1_000_000
                    ),
                    category: .diagnosticsCapture,
                    payload: payload
                )
            )
        }
        if state != .empty {
            append(.simulationStep(SimulationStepDiagnostics(
                tick: SimulationTick(rawValue: 120),
                didRunSimulationSystems: true,
                durationNanoseconds: 110_000
            )))
            append(.renderProjection(RenderProjectionDiagnostics(
                sourceTick: SimulationTick(rawValue: 119),
                publishedPresentationCount: 6,
                acceptedInstanceCount: 6,
                rejectedPresentationCount: 0,
                durationNanoseconds: 32_000
            )))
            append(.renderFrameCPU(RenderFrameCPUDiagnostics(
                frameSequence: RenderFrameSequence(rawValue: 80),
                sourceTick: SimulationTick(rawValue: 119),
                didSourceTickChange: true,
                submittedInstanceCount: 6,
                renderPassCount: 2,
                drawCount: 6,
                submeshCount: 6,
                wasTruncated: false,
                result: .submitted,
                durationNanoseconds: 420_000
            )))
        }
        if state == .backlog {
            append(.simulationPoll(SimulationPollDiagnostics(
                completedTick: SimulationTick(rawValue: 120),
                sampledWallDeltaNanoseconds: 40_000_000,
                stepsCompleted: 2,
                backlogBeforeNanoseconds: 35_000_000,
                backlogAfterNanoseconds: 18_000_000,
                durationNanoseconds: 250_000
            )))
        }
        if state == .renderError {
            append(.renderResourceFailure(RenderResourceFailureDiagnostics(
                stage: .pipeline,
                errorType: "FixturePipelineError"
            )))
        }
        return DiagnosticsDashboardPresentation(
            snapshot: DiagnosticsSnapshot(
                sessionID: sessionID,
                isCollectionEnabled: true,
                recentSampleCapacity: 256,
                totalSamplesReceived: samples.count,
                recentSamples: samples,
                aggregates: []
            )
        )
    }
}
#endif
