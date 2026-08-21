import Testing
@testable import Engine2

struct HeadlessSimulationTests {
    @Test func environmentConstructionUsesDocumentedDefaults() throws {
        let configuration = try HeadlessSimulationConfiguration(environment: [:])

        #expect(configuration.entityCount == 100_000)
        #expect(configuration.warmupTickCount == 10)
        #expect(configuration.measuredTickCount == 60)
    }

    @Test func environmentConstructionRejectsANonpositiveOverride() {
        do {
            _ = try HeadlessSimulationConfiguration(
                environment: ["ENGINE2_HEADLESS_ENTITY_COUNT": "0"]
            )
            Issue.record("Expected the headless configuration to reject a zero entity count.")
        } catch {
            #expect(
                error.description
                == "ENGINE2_HEADLESS_ENTITY_COUNT must contain a positive integer; received 0."
            )
        }
    }

    @Test func resultComputesTheMeasuredTickDistribution() throws {
        let configuration = try HeadlessSimulationConfiguration(
            entityCount: 5,
            warmupTickCount: 2,
            measuredTickCount: 5
        )
        let sessionID = SimulationSessionID()
        let initialCursor = SimulationCursor(
            sessionID: sessionID,
            tick: SimulationTick(rawValue: 2)
        )
        let finalCursor = SimulationCursor(
            sessionID: sessionID,
            tick: SimulationTick(rawValue: 7)
        )
        let result = HeadlessSimulationResult(
            configuration: configuration,
            constructionDuration: .milliseconds(7),
            tickDurations: [
                .milliseconds(5),
                .milliseconds(1),
                .milliseconds(3),
                .milliseconds(2),
                .milliseconds(4)
            ],
            initialMeasuredCursor: initialCursor,
            finalCursor: finalCursor,
            firstEntityPosition: SIMD3<Double>(1, 2, 3),
            lastEntityPosition: SIMD3<Double>(4, 5, 6),
            firstEntityRotation: .identity
        )

        #expect(abs(result.constructionMilliseconds - 7) < 0.0001)
        #expect(abs(result.totalMeasuredMilliseconds - 15) < 0.0001)
        #expect(abs(result.minimumTickMilliseconds - 1) < 0.0001)
        #expect(abs(result.medianTickMilliseconds - 3) < 0.0001)
        #expect(abs(result.meanTickMilliseconds - 3) < 0.0001)
        #expect(abs(result.p95TickMilliseconds - 5) < 0.0001)
        #expect(abs(result.maximumTickMilliseconds - 5) < 0.0001)
        #expect(result.initialMeasuredCursor == initialCursor)
        #expect(result.finalCursor == finalCursor)
        #expect(result.description.contains("fixed timestep:"))
        #expect(result.description.contains("first position: (1.000, 2.000, 3.000)"))
    }

    @Test func smallHeadlessWorkloadAdvancesEveryExactTick() async throws {
        let configuration = try HeadlessSimulationConfiguration(
            entityCount: 16,
            warmupTickCount: 2,
            measuredTickCount: 3
        )
        let runner = HeadlessSimulationRunner(configuration: configuration)

        let result = try await runner.run()

        #expect(result.initialMeasuredCursor.tick == SimulationTick(rawValue: 2))
        #expect(result.finalCursor.tick == SimulationTick(rawValue: 5))
        #expect(result.totalMeasuredMilliseconds > 0)
        #expect(result.minimumTickMilliseconds <= result.medianTickMilliseconds)
        #expect(result.medianTickMilliseconds <= result.maximumTickMilliseconds)
        #expect(result.firstEntityPosition.isFinite)
        #expect(result.lastEntityPosition.isFinite)
    }

    @Test func longHeadlessRunAcceptsRotationReturningNearIdentity() async throws {
        let configuration = try HeadlessSimulationConfiguration(
            entityCount: 1,
            warmupTickCount: 12_600,
            measuredTickCount: 1
        )
        let runner = HeadlessSimulationRunner(configuration: configuration)

        let result = try await runner.run()

        #expect(result.finalCursor.tick == SimulationTick(rawValue: 12_601))
        #expect(result.firstEntityRotation.vector.isFinite)
    }
}
