//
//  GameLoopTests.swift
//  Engine2Tests
//
//  Created by Codex on 3/15/26.
//

import Foundation
import Testing
@testable import Engine2

private final class SampledInstantSource {
    private let samples: [SuspendingClock.Instant]
    private var nextIndex = 0

    init(samples: [SuspendingClock.Instant]) {
        self.samples = samples
    }

    func next() -> SuspendingClock.Instant {
        let sample = samples[min(nextIndex, samples.count - 1)]
        nextIndex += 1
        return sample
    }
}

private actor TestSleeper {
    private let results: [Result<Void, any Error>]
    private var nextIndex = 0
    private var requestedDurations: [Duration] = []

    init(results: [Result<Void, any Error>]) {
        self.results = results
    }

    func sleep(for duration: Duration) async throws {
        requestedDurations.append(duration)
        let index = min(nextIndex, results.count - 1)
        nextIndex += 1
        try results[index].get()
    }

    func recordedDurations() -> [Duration] {
        requestedDurations
    }
}

struct GameLoopTests {
    @Test @MainActor func appTaskFeedsElapsedTimeIntoEngine() async throws {
        let world = World()
        let entity = EntityID(index: 0, generation: 0)

        world.positionComponents.insert(CPosition(position: SIMD3<Float>(1, 2, 3)), for: entity)
        world.velocityComponents.insert(CVelocity(velocity: SIMD3<Float>(4, 5, 6)), for: entity)
        world.motionAccumulatorComponents.insert(
            CMotionAccumulator(
                acceleration: SIMD3<Float>(2, 0, -2),
                impulse: SIMD3<Float>(1, -1, 0.5)
            ),
            for: entity
        )

        let engine = Engine(world: world, fixedTimeStep: .milliseconds(500), systems: [SMovement()])
        let baseInstant = SuspendingClock().now
        let instantSource = SampledInstantSource(
            samples: [
                baseInstant,
                baseInstant.advanced(by: .milliseconds(500))
            ]
        )
        let sleeper = TestSleeper(
            results: [
                .success(()),
                .failure(CancellationError())
            ]
        )
        let gameLoop = GameLoop(
            engine: engine,
            pollInterval: .milliseconds(500),
            clockFactory: {
                SystemClock(timeSource: instantSource.next)
            },
            sleeper: sleeper.sleep(for:)
        )

        gameLoop.start()

        for _ in 0..<100 {
            if !gameLoop.isRunning {
                break
            }

            await Task.yield()
        }

        #expect(gameLoop.isRunning == false)
        #expect(world.velocityComponents[entity]?.velocity == SIMD3<Float>(6, 4, 5.5))
        #expect(world.positionComponents[entity]?.position == SIMD3<Float>(4, 4, 5.75))
        #expect(engine.accumulatedTime == .zero)
    }

    @Test @MainActor func appTaskRebasesSleepAgainstAbsoluteDeadlinesAfterOversleep() async throws {
        let engine = Engine(world: World(), fixedTimeStep: .milliseconds(100), systems: [])
        let baseInstant = SuspendingClock().now
        let engineTimeSource = SampledInstantSource(
            samples: [
                baseInstant,
                baseInstant.advanced(by: .milliseconds(110))
            ]
        )
        let scheduleTimeSource = SampledInstantSource(
            samples: [
                baseInstant,
                baseInstant,
                baseInstant.advanced(by: .milliseconds(110)),
                baseInstant.advanced(by: .milliseconds(110))
            ]
        )
        let sleeper = TestSleeper(
            results: [
                .success(()),
                .failure(CancellationError())
            ]
        )
        let gameLoop = GameLoop(
            engine: engine,
            pollInterval: .milliseconds(100),
            clockFactory: {
                SystemClock(timeSource: engineTimeSource.next)
            },
            scheduleTimeSource: scheduleTimeSource.next,
            sleeper: sleeper.sleep(for:)
        )

        gameLoop.start()

        for _ in 0..<100 {
            if !gameLoop.isRunning {
                break
            }

            await Task.yield()
        }

        let requestedDurations = await sleeper.recordedDurations()

        #expect(gameLoop.isRunning == false)
        #expect(requestedDurations == [.milliseconds(100), .milliseconds(90)])
        #expect(engine.accumulatedTime == .milliseconds(10))
    }
}
