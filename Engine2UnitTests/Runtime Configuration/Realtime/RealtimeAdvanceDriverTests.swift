import Foundation
import Testing
@testable import Engine2

struct RealtimeAdvanceDriverTests {
    @Test func substepElapsedTimeAccumulatesUntilOneExactStepIsReady() async {
        let cursor = makeCursor()
        let target = RecordingAdvanceTarget(cursor: cursor)
        let baseInstant = SuspendingClock().now
        let elapsedSource = SampledInstantSource(
            samples: [
                baseInstant,
                baseInstant.advanced(by: .milliseconds(40)),
                baseInstant.advanced(by: .milliseconds(80)),
                baseInstant.advanced(by: .milliseconds(120))
            ]
        )
        let cancellation = CancellationError()
        let sleeper = ImmediateSleeper(
            results: [
                .success(()),
                .success(()),
                .success(()),
                .failure(cancellation)
            ]
        )
        let driver = makeDriver(
            target: target,
            inputSource: nil,
            cursor: cursor,
            fixedTimeStep: .milliseconds(100),
            pollInterval: .milliseconds(40),
            clockFactory: { SystemClock(timeSource: elapsedSource.next) },
            baseInstant: baseInstant,
            sleeper: sleeper.sleep(until:)
        )

        driver.start()
        let didRecordRequest = await eventually {
            await target.requestCount() == 1
        }
        driver.stop()

        let requests = await target.recordedRequests()
        #expect(didRecordRequest)
        #expect(requests.count == 1)
        #expect(requests.first?.stepCount.rawValue == 1)
    }

    @Test func oneWakeCanRequestMultipleStepsAndCarryItsRemainder() async {
        let cursor = makeCursor()
        let target = RecordingAdvanceTarget(cursor: cursor)
        let baseInstant = SuspendingClock().now
        let elapsedSource = SampledInstantSource(
            samples: [
                baseInstant,
                baseInstant.advanced(by: .milliseconds(250)),
                baseInstant.advanced(by: .milliseconds(300))
            ]
        )
        let cancellation = CancellationError()
        let sleeper = ImmediateSleeper(
            results: [.success(()), .success(()), .failure(cancellation)]
        )
        let driver = makeDriver(
            target: target,
            inputSource: nil,
            cursor: cursor,
            fixedTimeStep: .milliseconds(100),
            pollInterval: .milliseconds(100),
            clockFactory: { SystemClock(timeSource: elapsedSource.next) },
            baseInstant: baseInstant,
            sleeper: sleeper.sleep(until:)
        )

        driver.start()
        let didRecordRequests = await eventually {
            await target.requestCount() == 2
        }
        driver.stop()

        let requests = await target.recordedRequests()
        let expectedSecondTick = SimulationTick(rawValue: 2)
        #expect(didRecordRequests)
        #expect(requests.map(\.stepCount.rawValue) == [2, 1])
        #expect(requests[0].expectedCursor == cursor)
        #expect(requests[1].expectedCursor?.tick == expectedSecondTick)
    }

    @Test func preservePolicyCapsOneWakeThenDrainsBacklog() async {
        let cursor = makeCursor()
        let target = RecordingAdvanceTarget(cursor: cursor)
        let baseInstant = SuspendingClock().now
        let elapsedSource = SampledInstantSource(
            samples: [
                baseInstant,
                baseInstant.advanced(by: .milliseconds(550)),
                baseInstant.advanced(by: .milliseconds(550))
            ]
        )
        let cancellation = CancellationError()
        let sleeper = ImmediateSleeper(
            results: [.success(()), .success(()), .failure(cancellation)]
        )
        let maximumStepsPerWake = SimulationStepCount(rawValue: 3)
        let catchUpPolicy = RealtimeCatchUpPolicy(
            maximumStepsPerWake: maximumStepsPerWake,
            backlogTreatment: .preserve
        )
        let driver = RealtimeAdvanceDriver(
            advanceTarget: target,
            inputSource: nil,
            initialCursor: cursor,
            fixedTimeStep: .milliseconds(100),
            pollInterval: .milliseconds(100),
            catchUpPolicy: catchUpPolicy,
            isAdvancementEnabled: true,
            clockFactory: { SystemClock(timeSource: elapsedSource.next) },
            scheduleTimeSource: { baseInstant },
            sleeper: sleeper.sleep(until:)
        )

        driver.start()
        let didRecordRequests = await eventually {
            await target.requestCount() == 2
        }
        driver.stop()

        #expect(didRecordRequests)
        #expect(await target.recordedRequests().map(\.stepCount.rawValue) == [3, 2])
    }

    @Test func discardPolicyDropsOnlyOverflowingWholeStepDebt() async {
        let cursor = makeCursor()
        let target = RecordingAdvanceTarget(cursor: cursor)
        let baseInstant = SuspendingClock().now
        let elapsedSource = SampledInstantSource(
            samples: [
                baseInstant,
                baseInstant.advanced(by: .milliseconds(550)),
                baseInstant.advanced(by: .milliseconds(600))
            ]
        )
        let cancellation = CancellationError()
        let sleeper = ImmediateSleeper(
            results: [.success(()), .success(()), .failure(cancellation)]
        )
        let maximumStepsPerWake = SimulationStepCount(rawValue: 3)
        let catchUpPolicy = RealtimeCatchUpPolicy(
            maximumStepsPerWake: maximumStepsPerWake,
            backlogTreatment: .discardOverflow
        )
        let driver = RealtimeAdvanceDriver(
            advanceTarget: target,
            inputSource: nil,
            initialCursor: cursor,
            fixedTimeStep: .milliseconds(100),
            pollInterval: .milliseconds(100),
            catchUpPolicy: catchUpPolicy,
            isAdvancementEnabled: true,
            clockFactory: { SystemClock(timeSource: elapsedSource.next) },
            scheduleTimeSource: { baseInstant },
            sleeper: sleeper.sleep(until:)
        )

        driver.start()
        let didStop = await eventually { driver.isRunning == false }

        #expect(didStop)
        #expect(await target.recordedRequests().map(\.stepCount.rawValue) == [3])
    }

    @Test func discardPolicyRetainsFractionWhenNoWholeStepOverflows() async {
        let cursor = makeCursor()
        let target = RecordingAdvanceTarget(cursor: cursor)
        let baseInstant = SuspendingClock().now
        let elapsedSource = SampledInstantSource(
            samples: [
                baseInstant,
                baseInstant.advanced(by: .milliseconds(350)),
                baseInstant.advanced(by: .milliseconds(400))
            ]
        )
        let cancellation = CancellationError()
        let sleeper = ImmediateSleeper(
            results: [.success(()), .success(()), .failure(cancellation)]
        )
        let maximumStepsPerWake = SimulationStepCount(rawValue: 3)
        let catchUpPolicy = RealtimeCatchUpPolicy(
            maximumStepsPerWake: maximumStepsPerWake,
            backlogTreatment: .discardOverflow
        )
        let driver = RealtimeAdvanceDriver(
            advanceTarget: target,
            inputSource: nil,
            initialCursor: cursor,
            fixedTimeStep: .milliseconds(100),
            pollInterval: .milliseconds(100),
            catchUpPolicy: catchUpPolicy,
            isAdvancementEnabled: true,
            clockFactory: { SystemClock(timeSource: elapsedSource.next) },
            scheduleTimeSource: { baseInstant },
            sleeper: sleeper.sleep(until:)
        )

        driver.start()
        let didRecordRequests = await eventually {
            await target.requestCount() == 2
        }
        driver.stop()

        #expect(didRecordRequests)
        #expect(await target.recordedRequests().map(\.stepCount.rawValue) == [3, 1])
    }

    @Test func startBaselinePreservesInputPublishedBeforeFirstTick() async throws {
        let cursor = makeCursor()
        let target = RecordingAdvanceTarget(cursor: cursor)
        let expectedRevision = InputRevision(session: 4, sequence: 7)
        let expectedSnapshot = inputSnapshot(
            revision: expectedRevision,
            pointerMotionTotal: SIMD2<Float>(12, -3)
        )
        let laterRevision = InputRevision(session: 4, sequence: 8)
        let laterSnapshot = inputSnapshot(
            revision: laterRevision,
            pointerMotionTotal: SIMD2<Float>(99, 99)
        )
        let inputSource = SequencedInputSource(
            snapshots: [expectedSnapshot, laterSnapshot]
        )
        let baseInstant = SuspendingClock().now
        let elapsedSource = SampledInstantSource(
            samples: [baseInstant, baseInstant.advanced(by: .milliseconds(100))]
        )
        let cancellation = CancellationError()
        let sleeper = ImmediateSleeper(
            results: [.success(()), .failure(cancellation)]
        )
        let driver = makeDriver(
            target: target,
            inputSource: inputSource,
            cursor: cursor,
            fixedTimeStep: .milliseconds(100),
            pollInterval: .milliseconds(100),
            clockFactory: { SystemClock(timeSource: elapsedSource.next) },
            baseInstant: baseInstant,
            sleeper: sleeper.sleep(until:)
        )

        driver.start()
        let didRecordRequest = await eventually {
            await target.requestCount() == 1
        }
        driver.stop()

        let request = try #require(await target.recordedRequests().first)
        guard case let .rebaseThenIngest(
            baseline,
            snapshot
        ) = request.inputAssignment else {
            Issue.record("A fresh run must carry its start baseline and later input together.")
            return
        }

        #expect(didRecordRequest)
        #expect(inputSource.readCount == 2)
        #expect(baseline == expectedSnapshot)
        #expect(snapshot == laterSnapshot)
    }

    @Test func pauseDiscardsBacklogAndResumeRebasesInput() async throws {
        let cursor = makeCursor()
        let target = RecordingAdvanceTarget(cursor: cursor)
        let firstRevision = InputRevision(session: 2, sequence: 1)
        let firstSnapshot = inputSnapshot(
            revision: firstRevision,
            pointerMotionTotal: SIMD2<Float>(6, 0)
        )
        let secondRevision = InputRevision(session: 2, sequence: 2)
        let secondPointerMotionTotal = SIMD2<Float>(10, 0)
        let secondSnapshot = inputSnapshot(
            revision: secondRevision,
            pointerMotionTotal: secondPointerMotionTotal
        )
        let thirdRevision = InputRevision(session: 2, sequence: 3)
        let thirdPointerMotionTotal = SIMD2<Float>(12, 0)
        let thirdSnapshot = inputSnapshot(
            revision: thirdRevision,
            pointerMotionTotal: thirdPointerMotionTotal
        )
        let inputSource = SequencedInputSource(
            snapshots: [firstSnapshot, secondSnapshot, thirdSnapshot]
        )
        let baseInstant = SuspendingClock().now
        let elapsedSource = SampledInstantSource(
            samples: [
                baseInstant,
                baseInstant.advanced(by: .milliseconds(50)),
                baseInstant.advanced(by: .milliseconds(150)),
                baseInstant.advanced(by: .milliseconds(250)),
                baseInstant.advanced(by: .milliseconds(350))
            ]
        )
        let sleeper = ControlledSleeper()
        let driver = makeDriver(
            target: target,
            inputSource: inputSource,
            cursor: cursor,
            fixedTimeStep: .milliseconds(100),
            pollInterval: .milliseconds(100),
            clockFactory: { SystemClock(timeSource: elapsedSource.next) },
            baseInstant: baseInstant,
            sleeper: sleeper.sleep(until:)
        )

        driver.start()
        await sleeper.waitForPendingCount(1)
        await sleeper.resumeNext()
        await sleeper.waitForPendingCount(1)
        #expect(await target.requestCount() == 0)

        driver.pauseAdvancement()
        #expect(driver.advancementState == .paused)
        await sleeper.resumeNext()
        await sleeper.waitForPendingCount(1)
        #expect(await target.requestCount() == 0)

        driver.resumeAdvancement()
        #expect(driver.advancementState == .enabled)
        await sleeper.resumeNext()
        await sleeper.waitForPendingCount(1)
        #expect(await target.requestCount() == 0)

        await sleeper.resumeNext()
        let didRecordRequest = await eventually {
            await target.requestCount() == 1
        }
        driver.stop()
        await sleeper.resumeAll()

        let request = try #require(await target.recordedRequests().first)
        guard case let .rebaseThenIngest(
            baseline,
            snapshot
        ) = request.inputAssignment else {
            Issue.record("Resume must preserve input published after its captured baseline.")
            return
        }

        #expect(didRecordRequest)
        #expect(request.stepCount.rawValue == 1)
        #expect(baseline.pointerMotionTotal == secondPointerMotionTotal)
        #expect(snapshot.pointerMotionTotal == thirdPointerMotionTotal)
    }

    @Test func startAndStopAreIdempotentAndPreservePausePreference() async {
        let cursor = makeCursor()
        let target = RecordingAdvanceTarget(cursor: cursor)
        let sleeper = ControlledSleeper()
        var clockCreationCount = 0
        let driver = RealtimeAdvanceDriver(
            advanceTarget: target,
            inputSource: nil,
            initialCursor: cursor,
            fixedTimeStep: .seconds(1),
            pollInterval: .seconds(1),
            catchUpPolicy: .interactive,
            isAdvancementEnabled: false,
            clockFactory: {
                clockCreationCount += 1
                return SystemClock()
            },
            scheduleTimeSource: { SuspendingClock().now },
            sleeper: sleeper.sleep(until:)
        )

        driver.start()
        driver.start()
        await sleeper.waitForPendingCount(1)

        #expect(driver.isRunning)
        #expect(driver.advancementState == .paused)
        #expect(driver.isAdvancementEnabled == false)
        #expect(clockCreationCount == 1)

        driver.stop()
        driver.stop()
        await sleeper.resumeAll()

        #expect(driver.isRunning == false)
        #expect(driver.isAdvancementEnabled == false)

        driver.start()
        await sleeper.waitForPendingCount(1)

        #expect(driver.isRunning)
        #expect(driver.isAdvancementEnabled == false)
        #expect(clockCreationCount == 2)

        driver.stop()
        await sleeper.resumeAll()
    }

    @Test func suspendedPollingTaskDoesNotRetainTheDriver() async {
        let cursor = makeCursor()
        let target = RecordingAdvanceTarget(cursor: cursor)
        let sleeper = ControlledSleeper()
        var driver: RealtimeAdvanceDriver? = RealtimeAdvanceDriver(
            advanceTarget: target,
            inputSource: nil,
            initialCursor: cursor,
            fixedTimeStep: .seconds(1),
            pollInterval: .seconds(1),
            catchUpPolicy: .interactive,
            isAdvancementEnabled: true,
            clockFactory: { SystemClock() },
            scheduleTimeSource: { SuspendingClock().now },
            sleeper: sleeper.sleep(until:)
        )
        weak let weakDriver = driver

        driver?.start()
        await sleeper.waitForPendingCount(1)
        driver = nil

        let didRelease = await eventually { weakDriver == nil }
        await sleeper.resumeAll()

        #expect(didRelease)
    }

    @Test func enabledStopAndRestartRebasesTheNextInputRequest() async throws {
        let cursor = makeCursor()
        let target = RecordingAdvanceTarget(cursor: cursor)
        let revision = InputRevision(session: 8, sequence: 1)
        let snapshot = inputSnapshot(
            revision: revision,
            pointerMotionTotal: SIMD2<Float>(3, 1)
        )
        let inputSource = SequencedInputSource(
            snapshots: [snapshot]
        )
        let baseInstant = SuspendingClock().now
        let firstElapsedSource = SampledInstantSource(
            samples: [baseInstant, baseInstant.advanced(by: .milliseconds(100))]
        )
        let secondElapsedSource = SampledInstantSource(
            samples: [baseInstant, baseInstant.advanced(by: .milliseconds(100))]
        )
        var clockCreationCount = 0
        let sleeper = ControlledSleeper()
        let driver = makeDriver(
            target: target,
            inputSource: inputSource,
            cursor: cursor,
            fixedTimeStep: .milliseconds(100),
            pollInterval: .milliseconds(100),
            clockFactory: {
                defer { clockCreationCount += 1 }
                let source = clockCreationCount == 0
                    ? firstElapsedSource
                    : secondElapsedSource
                return SystemClock(timeSource: source.next)
            },
            baseInstant: baseInstant,
            sleeper: sleeper.sleep(until:)
        )

        driver.start()
        await sleeper.waitForPendingCount(1)
        await sleeper.resumeNext()
        _ = await eventually { await target.requestCount() == 1 }
        driver.stop()
        await sleeper.resumeAll()

        driver.start()
        await sleeper.waitForPendingCount(1)
        await sleeper.resumeNext()
        let didRecordSecondRequest = await eventually {
            await target.requestCount() == 2
        }
        driver.stop()
        await sleeper.resumeAll()

        let requests = await target.recordedRequests()
        let secondRequest = try #require(requests.last)
        guard case .rebaseThenIngest = secondRequest.inputAssignment else {
            Issue.record("Restarting an enabled driver must carry a transition baseline.")
            return
        }

        #expect(didRecordSecondRequest)
        #expect(driver.isAdvancementEnabled)
        #expect(clockCreationCount == 2)
    }

    @Test func pollingUsesAbsoluteDeadlinesAfterOversleep() async {
        let cursor = makeCursor()
        let target = RecordingAdvanceTarget(cursor: cursor)
        let baseInstant = SuspendingClock().now
        let elapsedSource = SampledInstantSource(
            samples: [baseInstant, baseInstant.advanced(by: .milliseconds(110))]
        )
        let scheduleSource = SampledInstantSource(
            samples: [baseInstant, baseInstant.advanced(by: .milliseconds(110))]
        )
        let cancellation = CancellationError()
        let sleeper = ImmediateSleeper(
            results: [.success(()), .failure(cancellation)]
        )
        let driver = RealtimeAdvanceDriver(
            advanceTarget: target,
            inputSource: nil,
            initialCursor: cursor,
            fixedTimeStep: .milliseconds(100),
            pollInterval: .milliseconds(100),
            catchUpPolicy: .interactive,
            isAdvancementEnabled: true,
            clockFactory: { SystemClock(timeSource: elapsedSource.next) },
            scheduleTimeSource: scheduleSource.next,
            sleeper: sleeper.sleep(until:)
        )

        driver.start()
        let didStop = await eventually { driver.isRunning == false }
        let deadlines = await sleeper.recordedDeadlines()

        #expect(didStop)
        #expect(
            deadlines == [
                baseInstant.advanced(by: .milliseconds(100)),
                baseInstant.advanced(by: .milliseconds(200))
            ]
        )
    }

    @Test func staleWakeAfterStopAndRestartCannotRequestAnAdvance() async {
        let cursor = makeCursor()
        let target = RecordingAdvanceTarget(cursor: cursor)
        let baseInstant = SuspendingClock().now
        let firstElapsedSource = SampledInstantSource(samples: [baseInstant])
        let secondElapsedSource = SampledInstantSource(
            samples: [baseInstant, baseInstant.advanced(by: .milliseconds(100))]
        )
        var clockCreationCount = 0
        let sleeper = ControlledSleeper()
        let driver = makeDriver(
            target: target,
            inputSource: nil,
            cursor: cursor,
            fixedTimeStep: .milliseconds(100),
            pollInterval: .milliseconds(100),
            clockFactory: {
                defer { clockCreationCount += 1 }
                let source = clockCreationCount == 0
                    ? firstElapsedSource
                    : secondElapsedSource
                return SystemClock(timeSource: source.next)
            },
            baseInstant: baseInstant,
            sleeper: sleeper.sleep(until:)
        )

        driver.start()
        await sleeper.waitForPendingCount(1)
        driver.stop()
        driver.start()

        // The sole waiter belongs to the cancelled run and deliberately
        // ignores cancellation until resumed. The replacement run cannot
        // launch until this retiring authority releases its slot.
        await sleeper.resumeNext()
        await sleeper.waitForPendingCount(1)
        #expect(await target.requestCount() == 0)

        await sleeper.resumeNext()
        let didRecordRequest = await eventually {
            await target.requestCount() == 1
        }
        driver.stop()
        await sleeper.resumeAll()

        #expect(didRecordRequest)
        #expect(await target.requestCount() == 1)
    }

    @Test func cursorMismatchFaultsUntilTheAppSynchronizes() async throws {
        let initialCursor = makeCursor()
        let rebuiltSessionID = SimulationSessionID()
        let rebuiltCursor = makeCursor(
            sessionID: rebuiltSessionID,
            tick: .zero
        )
        let target = RecordingAdvanceTarget(
            cursor: initialCursor,
            mismatchCursors: [rebuiltCursor]
        )
        let inputSource = SequencedInputSource(snapshots: [.empty])
        let baseInstant = SuspendingClock().now
        let firstElapsedSource = SampledInstantSource(
            samples: [baseInstant, baseInstant.advanced(by: .milliseconds(100))]
        )
        let secondElapsedSource = SampledInstantSource(
            samples: [baseInstant, baseInstant.advanced(by: .milliseconds(100))]
        )
        var clockCreationCount = 0
        let cancellation = CancellationError()
        let sleeper = ImmediateSleeper(
            results: [.success(()), .success(()), .failure(cancellation)]
        )
        let driver = makeDriver(
            target: target,
            inputSource: inputSource,
            cursor: initialCursor,
            fixedTimeStep: .milliseconds(100),
            pollInterval: .milliseconds(100),
            clockFactory: {
                defer { clockCreationCount += 1 }
                let source = clockCreationCount == 0
                    ? firstElapsedSource
                    : secondElapsedSource
                return SystemClock(timeSource: source.next)
            },
            baseInstant: baseInstant,
            sleeper: sleeper.sleep(until:)
        )

        driver.start()
        let didFault = await eventually { driver.fault != nil }

        #expect(didFault)
        #expect(driver.isRunning == false)
        #expect(driver.isAdvancementEnabled == false)
        #expect(
            driver.advancementState
                == .faulted(
                    .cursorMismatch(
                        expected: initialCursor,
                        current: rebuiltCursor
                    )
                )
        )
        #expect(
            driver.fault == .cursorMismatch(
                expected: initialCursor,
                current: rebuiltCursor
            )
        )

        driver.resumeAdvancement()
        #expect(driver.isAdvancementEnabled == false)

        driver.synchronize(to: rebuiltCursor, inputBaseline: nil)
        #expect(driver.advancementState == .paused)
        driver.resumeAdvancement()
        #expect(driver.advancementState == .enabled)
        driver.start()
        let didCompleteAfterSynchronization = await eventually {
            await target.requestCount() == 2
        }
        driver.stop()

        let request = try #require(await target.recordedRequests().last)
        guard case .rebaseThenIngest = request.inputAssignment else {
            Issue.record("Synchronization must baseline the next input request.")
            return
        }

        #expect(didCompleteAfterSynchronization)
        #expect(driver.fault == nil)
        #expect(request.expectedCursor == rebuiltCursor)
    }

    @Test func retiringCompletionUpdatesCursorBeforeQueuedRestart() async throws {
        let initialCursor = makeCursor()
        let target = SuspendedAdvanceTarget()
        let baseInstant = SuspendingClock().now
        let firstElapsedSource = SampledInstantSource(
            samples: [baseInstant, baseInstant.advanced(by: .milliseconds(100))]
        )
        let secondElapsedSource = SampledInstantSource(
            samples: [baseInstant, baseInstant.advanced(by: .milliseconds(100))]
        )
        var clockCreationCount = 0
        let sleeper = ControlledSleeper()
        let driver = makeSuspendedDriver(
            target: target,
            cursor: initialCursor,
            baseInstant: baseInstant,
            clockFactory: {
                defer { clockCreationCount += 1 }
                let source = clockCreationCount == 0
                    ? firstElapsedSource
                    : secondElapsedSource
                return SystemClock(timeSource: source.next)
            },
            sleeper: sleeper.sleep(until:)
        )

        driver.start()
        await sleeper.waitForPendingCount(1)
        await sleeper.resumeNext()
        await target.waitForRequestCount(1)

        driver.stop()
        driver.start()

        #expect(driver.isRunning)
        #expect(clockCreationCount == 1)

        let firstRequest = try #require(await target.recordedRequests().first)
        let firstOutcome = completedOutcome(
            for: firstRequest,
            from: initialCursor
        )
        let firstFinalCursor = try completedCursor(from: firstOutcome)
        await target.resumeNext(with: firstOutcome)

        await sleeper.waitForPendingCount(1)
        #expect(clockCreationCount == 2)
        await sleeper.resumeNext()
        await target.waitForRequestCount(2)

        let secondRequest = try #require(await target.recordedRequests().last)
        #expect(secondRequest.expectedCursor == firstFinalCursor)

        driver.stop()
        await target.resumeNext(
            with: completedOutcome(
                for: secondRequest,
                from: firstFinalCursor
            )
        )
        await sleeper.resumeAll()
    }

    @Test func stopAndDrainWaitsForAnAlreadyIssuedRequest() async throws {
        let initialCursor = makeCursor()
        let target = SuspendedAdvanceTarget()
        let baseInstant = SuspendingClock().now
        let elapsedSource = SampledInstantSource(
            samples: [baseInstant, baseInstant.advanced(by: .milliseconds(100))]
        )
        let sleeper = ControlledSleeper()
        let driver = makeSuspendedDriver(
            target: target,
            cursor: initialCursor,
            baseInstant: baseInstant,
            clockFactory: { SystemClock(timeSource: elapsedSource.next) },
            sleeper: sleeper.sleep(until:)
        )

        driver.start()
        await sleeper.waitForPendingCount(1)
        await sleeper.resumeNext()
        await target.waitForRequestCount(1)
        #expect(driver.isQuiescent == false)

        let drainTask = Task {
            await driver.stopAndDrain()
        }
        await Task.yield()

        #expect(driver.isRunning == false)
        #expect(driver.isQuiescent == false)

        let request = try #require(await target.recordedRequests().first)
        await target.resumeNext(
            with: completedOutcome(
                for: request,
                from: initialCursor
            )
        )
        await drainTask.value

        #expect(driver.isQuiescent)
        await sleeper.resumeAll()
    }

    @Test func explicitSynchronizationSupersedesRetiringOldSessionResult() async throws {
        let initialCursor = makeCursor()
        let synchronizedSessionID = SimulationSessionID()
        let synchronizedCursor = makeCursor(sessionID: synchronizedSessionID)
        let target = SuspendedAdvanceTarget()
        let baseInstant = SuspendingClock().now
        let firstElapsedSource = SampledInstantSource(
            samples: [baseInstant, baseInstant.advanced(by: .milliseconds(100))]
        )
        let secondElapsedSource = SampledInstantSource(
            samples: [baseInstant, baseInstant.advanced(by: .milliseconds(100))]
        )
        var clockCreationCount = 0
        let sleeper = ControlledSleeper()
        let driver = makeSuspendedDriver(
            target: target,
            cursor: initialCursor,
            baseInstant: baseInstant,
            clockFactory: {
                defer { clockCreationCount += 1 }
                let source = clockCreationCount == 0
                    ? firstElapsedSource
                    : secondElapsedSource
                return SystemClock(timeSource: source.next)
            },
            sleeper: sleeper.sleep(until:)
        )

        driver.start()
        await sleeper.waitForPendingCount(1)
        await sleeper.resumeNext()
        await target.waitForRequestCount(1)

        driver.stop()
        driver.synchronize(to: synchronizedCursor, inputBaseline: nil)
        driver.start()

        let firstRequest = try #require(await target.recordedRequests().first)
        await target.resumeNext(
            with: completedOutcome(
                for: firstRequest,
                from: initialCursor
            )
        )

        await sleeper.waitForPendingCount(1)
        await sleeper.resumeNext()
        await target.waitForRequestCount(2)

        let secondRequest = try #require(await target.recordedRequests().last)
        #expect(secondRequest.expectedCursor == synchronizedCursor)

        driver.stop()
        await target.resumeNext(
            with: completedOutcome(
                for: secondRequest,
                from: synchronizedCursor
            )
        )
        await sleeper.resumeAll()
    }

    private func makeDriver(
        target: RecordingAdvanceTarget,
        inputSource: (any PInputSnapshotSource)?,
        cursor: SimulationCursor,
        fixedTimeStep: Duration,
        pollInterval: Duration,
        clockFactory: @escaping RealtimeAdvanceDriver.ClockFactory,
        baseInstant: SuspendingClock.Instant,
        sleeper: @escaping RealtimeAdvanceDriver.Sleeper
    ) -> RealtimeAdvanceDriver {
        RealtimeAdvanceDriver(
            advanceTarget: target,
            inputSource: inputSource,
            initialCursor: cursor,
            fixedTimeStep: fixedTimeStep,
            pollInterval: pollInterval,
            catchUpPolicy: .interactive,
            isAdvancementEnabled: true,
            clockFactory: clockFactory,
            scheduleTimeSource: { baseInstant },
            sleeper: sleeper
        )
    }

    private func makeSuspendedDriver(
        target: SuspendedAdvanceTarget,
        cursor: SimulationCursor,
        baseInstant: SuspendingClock.Instant,
        clockFactory: @escaping RealtimeAdvanceDriver.ClockFactory,
        sleeper: @escaping RealtimeAdvanceDriver.Sleeper
    ) -> RealtimeAdvanceDriver {
        RealtimeAdvanceDriver(
            advanceTarget: target,
            inputSource: nil,
            initialCursor: cursor,
            fixedTimeStep: .milliseconds(100),
            pollInterval: .milliseconds(100),
            catchUpPolicy: .interactive,
            isAdvancementEnabled: true,
            clockFactory: clockFactory,
            scheduleTimeSource: { baseInstant },
            sleeper: sleeper
        )
    }

    private func completedOutcome(
        for request: SimulationAdvanceRequest,
        from initialCursor: SimulationCursor
    ) -> SimulationAdvanceOutcome {
        let rawStepCount = UInt64(request.stepCount.rawValue)
        let finalTick = SimulationTick(
            rawValue: initialCursor.tick.rawValue + rawStepCount
        )
        let finalCursor = SimulationCursor(
            sessionID: initialCursor.sessionID,
            tick: finalTick
        )
        let completedStepCount = SimulationCompletedStepCount(
            rawValue: request.stepCount.rawValue
        )
        let finalPresentationSnapshot = SimulationPresentationSnapshot(
            cursor: finalCursor,
            camera: .standard,
            entityPresentations: []
        )
        let result = SimulationAdvanceResult(
            initialCursor: initialCursor,
            finalCursor: finalCursor,
            completedStepCount: completedStepCount,
            finalPresentationSnapshot: finalPresentationSnapshot
        )

        return .completed(result)
    }

    private func completedCursor(from outcome: SimulationAdvanceOutcome) throws -> SimulationCursor {
        guard case let .completed(result) = outcome else {
            Issue.record("Expected a completed outcome.")
            throw UnexpectedAdvanceOutcome()
        }

        return result.finalCursor
    }

    private func makeCursor(
        sessionID: SimulationSessionID = SimulationSessionID(),
        tick: SimulationTick = .zero
    ) -> SimulationCursor {
        SimulationCursor(sessionID: sessionID, tick: tick)
    }

    private func inputSnapshot(revision: InputRevision, pointerMotionTotal: SIMD2<Float>) -> InputSnapshot {
        InputSnapshot(
            revision: revision,
            pointerPosition: pointerMotionTotal,
            pointerMotionTotal: pointerMotionTotal,
            scrollTotal: .zero,
            pressedMouseButtons: [],
            pressedKeys: []
        )
    }

    private func eventually(_ condition: () async -> Bool) async -> Bool {
        for _ in 0..<10_000 {
            if await condition() {
                return true
            }
            await Task.yield()
        }

        return false
    }
}

private extension RealtimeAdvanceDriverTests {
    private struct UnexpectedAdvanceOutcome: Error {}

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

    private actor ImmediateSleeper {
        private let results: [Result<Void, any Error>]
        private var nextIndex = 0
        private var deadlines: [SuspendingClock.Instant] = []

        init(results: [Result<Void, any Error>]) {
            self.results = results
        }

        func sleep(until deadline: SuspendingClock.Instant) async throws {
            deadlines.append(deadline)
            let index = min(nextIndex, results.count - 1)
            nextIndex += 1
            try results[index].get()
        }

        func recordedDeadlines() -> [SuspendingClock.Instant] {
            deadlines
        }
    }

    private actor ControlledSleeper {
        private struct Waiter {
            let continuation: CheckedContinuation<Void, any Error>
        }

        private var waiters: [Waiter] = []
        private var countWaiters: [
            Int: [CheckedContinuation<Void, Never>]
        ] = [:]

        func sleep(until deadline: SuspendingClock.Instant) async throws {
            try await withCheckedThrowingContinuation { continuation in
                let waiter = Waiter(continuation: continuation)
                waiters.append(waiter)
                resumeSatisfiedCountWaiters()
            }
        }

        func waitForPendingCount(_ count: Int) async {
            guard waiters.count < count else {
                return
            }

            await withCheckedContinuation { continuation in
                countWaiters[count, default: []].append(continuation)
            }
        }

        func resumeNext() {
            guard waiters.isEmpty == false else {
                Issue.record("No controlled sleep was pending.")
                return
            }

            waiters.removeFirst().continuation.resume()
        }

        func resumeAll() {
            let pendingWaiters = waiters
            waiters.removeAll()
            for waiter in pendingWaiters {
                waiter.continuation.resume()
            }
        }

        private func resumeSatisfiedCountWaiters() {
            let satisfiedCounts = countWaiters.keys.filter {
                $0 <= waiters.count
            }
            for count in satisfiedCounts {
                let continuations = countWaiters.removeValue(forKey: count) ?? []
                continuations.forEach { $0.resume() }
            }
        }
    }

    private actor RecordingAdvanceTarget: PSimulationAdvanceTarget {
        private var cursor: SimulationCursor
        private var requests: [SimulationAdvanceRequest] = []
        private var mismatchCursors: [SimulationCursor]

        init(cursor: SimulationCursor, mismatchCursors: [SimulationCursor] = []) {
            self.cursor = cursor
            self.mismatchCursors = mismatchCursors
        }

        func advance(_ request: SimulationAdvanceRequest) async -> SimulationAdvanceOutcome {
            requests.append(request)

            if mismatchCursors.isEmpty == false {
                let current = mismatchCursors.removeFirst()
                cursor = current
                return .rejected(
                    .cursorMismatch(
                        expected: request.expectedCursor ?? cursor,
                        current: current
                    )
                )
            }

            let initialCursor = cursor
            let rawStepCount = UInt64(request.stepCount.rawValue)
            let finalTick = SimulationTick(
                rawValue: cursor.tick.rawValue + rawStepCount
            )
            let finalCursor = SimulationCursor(
                sessionID: cursor.sessionID,
                tick: finalTick
            )
            cursor = finalCursor
            let completedStepCount = SimulationCompletedStepCount(
                rawValue: request.stepCount.rawValue
            )
            let finalPresentationSnapshot = SimulationPresentationSnapshot(
                cursor: finalCursor,
                camera: .standard,
                entityPresentations: []
            )
            let result = SimulationAdvanceResult(
                initialCursor: initialCursor,
                finalCursor: finalCursor,
                completedStepCount: completedStepCount,
                finalPresentationSnapshot: finalPresentationSnapshot
            )

            return .completed(result)
        }

        func requestCount() -> Int {
            requests.count
        }

        func recordedRequests() -> [SimulationAdvanceRequest] {
            requests
        }
    }

    private actor SuspendedAdvanceTarget: PSimulationAdvanceTarget {
        private struct PendingAdvance {
            let continuation: CheckedContinuation<SimulationAdvanceOutcome, Never>
        }

        private var requests: [SimulationAdvanceRequest] = []
        private var pendingAdvances: [PendingAdvance] = []
        private var countWaiters: [
            Int: [CheckedContinuation<Void, Never>]
        ] = [:]

        func advance(_ request: SimulationAdvanceRequest) async -> SimulationAdvanceOutcome {
            requests.append(request)

            return await withCheckedContinuation { continuation in
                let pendingAdvance = PendingAdvance(
                    continuation: continuation
                )
                pendingAdvances.append(pendingAdvance)
                resumeSatisfiedCountWaiters()
            }
        }

        func waitForRequestCount(_ count: Int) async {
            guard requests.count < count else {
                return
            }

            await withCheckedContinuation { continuation in
                countWaiters[count, default: []].append(continuation)
            }
        }

        func resumeNext(with outcome: SimulationAdvanceOutcome) {
            guard pendingAdvances.isEmpty == false else {
                Issue.record("No suspended advance was pending.")
                return
            }

            pendingAdvances.removeFirst().continuation.resume(returning: outcome)
        }

        func recordedRequests() -> [SimulationAdvanceRequest] {
            requests
        }

        private func resumeSatisfiedCountWaiters() {
            let satisfiedCounts = countWaiters.keys.filter {
                $0 <= requests.count
            }
            for count in satisfiedCounts {
                let continuations = countWaiters.removeValue(forKey: count) ?? []
                continuations.forEach { $0.resume() }
            }
        }
    }

    private final class SequencedInputSource: PInputSnapshotSource {
        private let snapshots: [InputSnapshot]
        private(set) var readCount = 0

        var latestInputSnapshot: InputSnapshot {
            let snapshot = snapshots[min(readCount, snapshots.count - 1)]
            readCount += 1
            return snapshot
        }

        init(snapshots: [InputSnapshot]) {
            precondition(snapshots.isEmpty == false)
            self.snapshots = snapshots
        }
    }
}
