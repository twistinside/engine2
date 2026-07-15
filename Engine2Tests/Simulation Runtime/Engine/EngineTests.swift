//
//  EngineTests.swift
//  Engine2Tests
//
//  Created by Codex on 3/10/26.
//

import Testing
@testable import Engine2

struct EngineTests {
    @Test func defaultFixedTimeStepIsPositive() async throws {
        let engine = Engine()

        #expect(engine.fixedTimeStep > .zero)
    }

    @Test func updateAccumulatesTimeUntilFixedStepBoundary() async throws {
        let world = World()
        let entity = EntityID(index: 0, generation: 0)
        var motion = CMotion(
            velocity: SIMD3<Float>(4, 5, 6),
            impulse: SIMD3<Float>(1, -1, 0.5)
        )
        motion.accumulator.acceleration = SIMD3<Float>(2, 0, -2)

        world.positionComponents.insert(CPosition(position: SIMD3<Float>(1, 2, 3)), for: entity)
        world.motionComponents.insert(motion, for: entity)

        let engine = Engine(world: world, fixedTimeStep: .milliseconds(500), systems: [SMovement()])

        engine.update(deltaTime: .milliseconds(490))

        #expect(world.motionComponents[entity]?.velocity == SIMD3<Float>(4, 5, 6))
        #expect(world.positionComponents[entity]?.position == SIMD3<Float>(1, 2, 3))
        #expect(engine.accumulatedTime == .milliseconds(490))

        engine.update(deltaTime: .milliseconds(10))

        #expect(world.motionComponents[entity]?.velocity == SIMD3<Float>(6, 4, 5.5))
        #expect(world.positionComponents[entity]?.position == SIMD3<Float>(4, 4, 5.75))
        #expect(engine.accumulatedTime == .zero)
    }

    @Test func tickConsumesDeltaTimeFromClock() async throws {
        let world = World()
        let entity = EntityID(index: 0, generation: 0)
        var motion = CMotion(
            velocity: SIMD3<Float>(4, 5, 6),
            impulse: SIMD3<Float>(1, -1, 0.5)
        )
        motion.accumulator.acceleration = SIMD3<Float>(2, 0, -2)

        world.positionComponents.insert(CPosition(position: SIMD3<Float>(1, 2, 3)), for: entity)
        world.motionComponents.insert(motion, for: entity)

        let engine = Engine(world: world, fixedTimeStep: .milliseconds(500), systems: [SMovement()])
        var clock = ManualClock()

        clock.advance(by: .milliseconds(490))
        engine.tick(using: &clock)

        #expect(world.motionComponents[entity]?.velocity == SIMD3<Float>(4, 5, 6))
        #expect(world.positionComponents[entity]?.position == SIMD3<Float>(1, 2, 3))
        #expect(engine.accumulatedTime == .milliseconds(490))

        clock.advance(by: .milliseconds(10))
        engine.tick(using: &clock)

        #expect(world.motionComponents[entity]?.velocity == SIMD3<Float>(6, 4, 5.5))
        #expect(world.positionComponents[entity]?.position == SIMD3<Float>(4, 4, 5.75))
        #expect(engine.accumulatedTime == .zero)
    }

    @Test func pausedUpdateRunsAlwaysSystemsButSkipsSimulationSystems() async throws {
        let world = World()
        let entity = EntityID(index: 0, generation: 0)

        world.positionComponents.insert(CPosition(position: .zero), for: entity)
        world.motionComponents.insert(
            CMotion(velocity: SIMD3<Float>(10, 0, 0)),
            for: entity
        )
        world.input.apply(.mouseButtonDown(.left, position: .zero))

        let engine = Engine(
            world: world,
            fixedTimeStep: .milliseconds(100),
            alwaysSystems: [SInputHistory(), SInputCleanup()],
            systems: [SMovement()]
        )
        engine.isSimulationRunning = false

        engine.update(deltaTime: .milliseconds(100))

        #expect(world.positionComponents[entity]?.position == .zero)
        #expect(world.input.history.count == 1)
        #expect(world.input.history[0].tokens == ["LMB"])
        #expect(engine.accumulatedTime == .zero)
    }

    @Test func updateRunsMultipleFixedStepsAndRetainsRemainder() {
        let world = World()
        let engine = Engine(
            world: world,
            fixedTimeStep: .milliseconds(100),
            alwaysSystems: [],
            systems: [StatefulSystem()]
        )

        engine.update(deltaTime: .milliseconds(250))

        #expect(world.camera.position.x == 2)
        #expect(engine.accumulatedTime == .milliseconds(50))
    }

    @Test func appendedSystemsRunInAlwaysThenSimulationOrder() {
        let recorder = ExecutionRecorder()
        let engine = Engine(alwaysSystems: [], systems: [])

        engine.addSystem(RecordingSystem(name: "simulation", recorder: recorder))
        engine.addAlwaysSystem(RecordingSystem(name: "always", recorder: recorder))
        engine.step()

        #expect(recorder.entries == ["always", "simulation"])
    }
}

private struct StatefulSystem: PSystem {
    private var updateCount: Float = 0

    mutating func update(world: inout World, deltaTime: Float) {
        updateCount += 1
        world.camera.position.x = updateCount
    }
}

private final class ExecutionRecorder {
    var entries: [String] = []
}

private struct RecordingSystem: PSystem {
    let name: String
    let recorder: ExecutionRecorder

    mutating func update(world: inout World, deltaTime: Float) {
        recorder.entries.append(name)
    }
}
