import Foundation
import Testing
@testable import Engine2
@testable import Engine2RealtimeAssembly

struct RealtimeAdvanceDriverTests {
    @Test func substepElapsedTimeAccumulatesUntilOneExactStepIsReady() async {
        let cursor = makeCursor()
        let target = RecordingAdvanceTarget(cursor: cursor)
        let baseInstant = SuspendingClock().now
        let clock = TestRealtimeClock(
            initialInstant: baseInstant,
            suspension: .immediate(
                wakes: [
                    (
                        instant: baseInstant.advanced(by: .milliseconds(40)),
                        result: .success(())
                    ),
                    (
                        instant: baseInstant.advanced(by: .milliseconds(80)),
                        result: .success(())
                    ),
                    (
                        instant: baseInstant.advanced(by: .milliseconds(120)),
                        result: .success(())
                    ),
                    (
                        instant: baseInstant.advanced(by: .milliseconds(120)),
                        result: .failure(CancellationError())
                    )
                ]
            )
        )
        let driver = makeDriver(
            target: target,
            inputSource: nil,
            cursor: cursor,
            fixedTimeStep: .milliseconds(100),
            pollInterval: .milliseconds(40),
            clock: clock
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
        let clock = TestRealtimeClock(
            initialInstant: baseInstant,
            suspension: .immediate(
                wakes: [
                    (
                        instant: baseInstant.advanced(by: .milliseconds(250)),
                        result: .success(())
                    ),
                    (
                        instant: baseInstant.advanced(by: .milliseconds(300)),
                        result: .success(())
                    ),
                    (
                        instant: baseInstant.advanced(by: .milliseconds(300)),
                        result: .failure(CancellationError())
                    )
                ]
            )
        )
        let driver = makeDriver(
            target: target,
            inputSource: nil,
            cursor: cursor,
            fixedTimeStep: .milliseconds(100),
            pollInterval: .milliseconds(100),
            clock: clock
        )

        driver.start()
        let didRecordRequests = await eventually {
            await target.requestCount() == 2
        }
        driver.stop()

        let requests = await target.recordedRequests()
        #expect(didRecordRequests)
        #expect(requests.map(\.stepCount.rawValue) == [2, 1])
        #expect(requests[0].expectedCursor == cursor)
        #expect(requests[1].expectedCursor?.tick == SimulationTick(rawValue: 2))
    }

    @Test func backwardClockSampleContributesZeroElapsedTime() async {
        let cursor = makeCursor()
        let target = RecordingAdvanceTarget(cursor: cursor)
        let baseInstant = SuspendingClock().now
        let clock = NonmonotonicTestClock(
            initialInstant: baseInstant,
            wakes: [
                (
                    instant: baseInstant.advanced(by: .milliseconds(50)),
                    result: .success(())
                ),
                (
                    instant: baseInstant.advanced(by: .milliseconds(-50)),
                    result: .success(())
                ),
                (
                    instant: baseInstant,
                    result: .success(())
                ),
                (
                    instant: baseInstant,
                    result: .failure(CancellationError())
                )
            ]
        )
        let driver = makeDriver(
            target: target,
            inputSource: nil,
            cursor: cursor,
            fixedTimeStep: .milliseconds(100),
            pollInterval: .milliseconds(50),
            clock: clock
        )

        driver.start()
        let didRecordRequest = await eventually {
            await target.requestCount() == 1
        }
        driver.stop()

        let requests = await target.recordedRequests()
        #expect(didRecordRequest)
        #expect(requests.map(\.stepCount.rawValue) == [1])
    }

    @Test func preservePolicyCapsOneWakeThenDrainsBacklog() async {
        let cursor = makeCursor()
        let target = RecordingAdvanceTarget(cursor: cursor)
        let baseInstant = SuspendingClock().now
        let clock = TestRealtimeClock(
            initialInstant: baseInstant,
            suspension: .immediate(
                wakes: [
                    (
                        instant: baseInstant.advanced(by: .milliseconds(450)),
                        result: .success(())
                    ),
                    (
                        instant: baseInstant.advanced(by: .milliseconds(500)),
                        result: .success(())
                    ),
                    (
                        instant: baseInstant.advanced(by: .milliseconds(500)),
                        result: .failure(CancellationError())
                    )
                ]
            )
        )
        let driver = RealtimeAdvanceDriver(
            advanceTarget: target,
            inputSource: nil,
            initialCursor: cursor,
            fixedTimeStep: .milliseconds(100),
            pollInterval: .milliseconds(100),
            catchUpPolicy: RealtimeCatchUpPolicy(
                maximumStepsPerWake: SimulationStepCount(rawValue: 3),
                backlogTreatment: .preserve
            ),
            isAdvancementEnabled: true,
            clock: clock
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
        let clock = TestRealtimeClock(
            initialInstant: baseInstant,
            suspension: .immediate(
                wakes: [
                    (
                        instant: baseInstant.advanced(by: .milliseconds(550)),
                        result: .success(())
                    ),
                    (
                        instant: baseInstant.advanced(by: .milliseconds(600)),
                        result: .success(())
                    ),
                    (
                        instant: baseInstant.advanced(by: .milliseconds(600)),
                        result: .failure(CancellationError())
                    )
                ]
            )
        )
        let driver = RealtimeAdvanceDriver(
            advanceTarget: target,
            inputSource: nil,
            initialCursor: cursor,
            fixedTimeStep: .milliseconds(100),
            pollInterval: .milliseconds(100),
            catchUpPolicy: RealtimeCatchUpPolicy(
                maximumStepsPerWake: SimulationStepCount(rawValue: 3),
                backlogTreatment: .discardOverflow
            ),
            isAdvancementEnabled: true,
            clock: clock
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
        let clock = TestRealtimeClock(
            initialInstant: baseInstant,
            suspension: .immediate(
                wakes: [
                    (
                        instant: baseInstant.advanced(by: .milliseconds(350)),
                        result: .success(())
                    ),
                    (
                        instant: baseInstant.advanced(by: .milliseconds(400)),
                        result: .success(())
                    ),
                    (
                        instant: baseInstant.advanced(by: .milliseconds(400)),
                        result: .failure(CancellationError())
                    )
                ]
            )
        )
        let driver = RealtimeAdvanceDriver(
            advanceTarget: target,
            inputSource: nil,
            initialCursor: cursor,
            fixedTimeStep: .milliseconds(100),
            pollInterval: .milliseconds(100),
            catchUpPolicy: RealtimeCatchUpPolicy(
                maximumStepsPerWake: SimulationStepCount(rawValue: 3),
                backlogTreatment: .discardOverflow
            ),
            isAdvancementEnabled: true,
            clock: clock
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
        let expectedSnapshot = inputSnapshot(
            revision: InputRevision(session: 4, sequence: 7),
            pointerMotionTotal: SIMD2<Float>(12, -3)
        )
        let laterSnapshot = inputSnapshot(
            revision: InputRevision(session: 4, sequence: 8),
            pointerMotionTotal: SIMD2<Float>(99, 99)
        )
        let inputSource = SequencedInputSource(
            snapshots: [expectedSnapshot, laterSnapshot]
        )
        let baseInstant = SuspendingClock().now
        let clock = TestRealtimeClock(
            initialInstant: baseInstant,
            suspension: .immediate(
                wakes: [
                    (
                        instant: baseInstant.advanced(by: .milliseconds(100)),
                        result: .success(())
                    ),
                    (
                        instant: baseInstant.advanced(by: .milliseconds(100)),
                        result: .failure(CancellationError())
                    )
                ]
            )
        )
        let driver = makeDriver(
            target: target,
            inputSource: inputSource,
            cursor: cursor,
            fixedTimeStep: .milliseconds(100),
            pollInterval: .milliseconds(100),
            clock: clock
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
        let secondPointerMotionTotal = SIMD2<Float>(10, 0)
        let thirdPointerMotionTotal = SIMD2<Float>(12, 0)
        let inputSource = SequencedInputSource(
            snapshots: [
                inputSnapshot(
                    revision: InputRevision(session: 2, sequence: 1),
                    pointerMotionTotal: SIMD2<Float>(6, 0)
                ),
                inputSnapshot(
                    revision: InputRevision(session: 2, sequence: 2),
                    pointerMotionTotal: secondPointerMotionTotal
                ),
                inputSnapshot(
                    revision: InputRevision(session: 2, sequence: 3),
                    pointerMotionTotal: thirdPointerMotionTotal
                )
            ]
        )
        let baseInstant = SuspendingClock().now
        let clock = TestRealtimeClock(
            initialInstant: baseInstant,
            suspension: .controlled
        )
        let driver = makeDriver(
            target: target,
            inputSource: inputSource,
            cursor: cursor,
            fixedTimeStep: .milliseconds(100),
            pollInterval: .milliseconds(50),
            clock: clock
        )

        driver.start()
        await clock.waitForPendingCount(1)
        let firstWakeInstant = baseInstant.advanced(by: .milliseconds(50))
        await clock.resumeNext(at: firstWakeInstant)
        await clock.waitForPendingCount(1)
        #expect(await target.requestCount() == 0)

        driver.pauseAdvancement()
        #expect(driver.advancementState == .paused)
        let pausedWakeInstant = baseInstant.advanced(by: .milliseconds(150))
        await clock.resumeNext(at: pausedWakeInstant)
        await clock.waitForPendingCount(1)
        #expect(await target.requestCount() == 0)

        driver.resumeAdvancement()
        #expect(driver.advancementState == .enabled)
        let baselineWakeInstant = baseInstant.advanced(by: .milliseconds(250))
        await clock.resumeNext(at: baselineWakeInstant)
        await clock.waitForPendingCount(1)
        #expect(await target.requestCount() == 0)

        let activeWakeInstant = baseInstant.advanced(by: .milliseconds(350))
        await clock.resumeNext(at: activeWakeInstant)
        let didRecordRequest = await eventually {
            await target.requestCount() == 1
        }
        driver.stop()
        await clock.resumeAll()

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
        let baseInstant = SuspendingClock().now
        let clock = TestRealtimeClock(
            initialInstant: baseInstant,
            suspension: .controlled
        )
        let driver = RealtimeAdvanceDriver(
            advanceTarget: target,
            inputSource: nil,
            initialCursor: cursor,
            fixedTimeStep: .seconds(1),
            pollInterval: .seconds(1),
            catchUpPolicy: .interactive,
            isAdvancementEnabled: false,
            clock: clock
        )

        driver.start()
        driver.start()
        await clock.waitForPendingCount(1)

        #expect(driver.isRunning)
        #expect(driver.advancementState == .paused)
        #expect(driver.isAdvancementEnabled == false)
        let firstDeadline = baseInstant.advanced(by: .seconds(1))
        #expect(await clock.recordedDeadlines() == [firstDeadline])

        driver.stop()
        driver.stop()
        await clock.resumeAll()

        #expect(driver.isRunning == false)
        #expect(driver.isAdvancementEnabled == false)

        let restartInstant = baseInstant.advanced(by: .seconds(10))
        await clock.setCurrentInstant(restartInstant)
        driver.start()
        await clock.waitForPendingCount(1)

        #expect(driver.isRunning)
        #expect(driver.isAdvancementEnabled == false)
        let restartDeadline = restartInstant.advanced(by: .seconds(1))
        #expect(
            await clock.recordedDeadlines()
                == [firstDeadline, restartDeadline]
        )

        driver.stop()
        await clock.resumeAll()
    }

    @Test func suspendedPollingTaskDoesNotRetainTheDriver() async {
        let cursor = makeCursor()
        let target = RecordingAdvanceTarget(cursor: cursor)
        let baseInstant = SuspendingClock().now
        let clock = TestRealtimeClock(
            initialInstant: baseInstant,
            suspension: .controlled
        )
        var driver: RealtimeAdvanceDriver? = RealtimeAdvanceDriver(
            advanceTarget: target,
            inputSource: nil,
            initialCursor: cursor,
            fixedTimeStep: .seconds(1),
            pollInterval: .seconds(1),
            catchUpPolicy: .interactive,
            isAdvancementEnabled: true,
            clock: clock
        )
        weak let weakDriver = driver

        driver?.start()
        await clock.waitForPendingCount(1)
        driver = nil

        let didRelease = await eventually { weakDriver == nil }
        await clock.resumeAll()

        #expect(didRelease)
    }

    @Test func enabledStopAndRestartRebasesTheNextInputRequest() async throws {
        let cursor = makeCursor()
        let target = RecordingAdvanceTarget(cursor: cursor)
        let inputSource = SequencedInputSource(
            snapshots: [
                inputSnapshot(
                    revision: InputRevision(session: 8, sequence: 1),
                    pointerMotionTotal: SIMD2<Float>(3, 1)
                )
            ]
        )
        let baseInstant = SuspendingClock().now
        let clock = TestRealtimeClock(
            initialInstant: baseInstant,
            suspension: .controlled
        )
        let driver = makeDriver(
            target: target,
            inputSource: inputSource,
            cursor: cursor,
            fixedTimeStep: .milliseconds(100),
            pollInterval: .milliseconds(100),
            clock: clock
        )

        driver.start()
        await clock.waitForPendingCount(1)
        let firstWakeInstant = baseInstant.advanced(by: .milliseconds(100))
        await clock.resumeNext(at: firstWakeInstant)
        _ = await eventually { await target.requestCount() == 1 }
        driver.stop()
        await clock.resumeAll()

        let restartInstant = baseInstant.advanced(by: .seconds(10))
        await clock.setCurrentInstant(restartInstant)
        driver.start()
        await clock.waitForPendingCount(1)
        let restartWakeInstant = restartInstant.advanced(by: .milliseconds(100))
        await clock.resumeNext(at: restartWakeInstant)
        let didRecordSecondRequest = await eventually {
            await target.requestCount() == 2
        }
        driver.stop()
        await clock.resumeAll()

        let requests = await target.recordedRequests()
        let secondRequest = try #require(requests.last)
        guard case .rebaseThenIngest = secondRequest.inputAssignment else {
            Issue.record("Restarting an enabled driver must carry a transition baseline.")
            return
        }

        #expect(didRecordSecondRequest)
        #expect(driver.isAdvancementEnabled)
        #expect(secondRequest.stepCount.rawValue == 1)
    }

    @Test func pollingUsesAbsoluteDeadlinesAfterOversleep() async {
        let cursor = makeCursor()
        let target = RecordingAdvanceTarget(cursor: cursor)
        let baseInstant = SuspendingClock().now
        let oversleptInstant = baseInstant.advanced(by: .milliseconds(110))
        let clock = TestRealtimeClock(
            initialInstant: baseInstant,
            suspension: .immediate(
                wakes: [
                    (instant: oversleptInstant, result: .success(())),
                    (
                        instant: oversleptInstant,
                        result: .failure(CancellationError())
                    )
                ]
            )
        )
        let driver = RealtimeAdvanceDriver(
            advanceTarget: target,
            inputSource: nil,
            initialCursor: cursor,
            fixedTimeStep: .milliseconds(100),
            pollInterval: .milliseconds(100),
            catchUpPolicy: .interactive,
            isAdvancementEnabled: true,
            clock: clock
        )

        driver.start()
        let didStop = await eventually { driver.isRunning == false }
        let deadlines = await clock.recordedDeadlines()

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
        let clock = TestRealtimeClock(
            initialInstant: baseInstant,
            suspension: .controlled
        )
        let driver = makeDriver(
            target: target,
            inputSource: nil,
            cursor: cursor,
            fixedTimeStep: .milliseconds(100),
            pollInterval: .milliseconds(100),
            clock: clock
        )

        driver.start()
        await clock.waitForPendingCount(1)
        driver.stop()
        driver.start()

        // The sole waiter belongs to the cancelled run and deliberately
        // ignores cancellation until resumed. The replacement run cannot
        // launch until this retiring authority releases its slot.
        let restartInstant = baseInstant.advanced(by: .seconds(10))
        await clock.resumeNext(at: restartInstant)
        await clock.waitForPendingCount(1)
        #expect(await target.requestCount() == 0)

        let restartWakeInstant = restartInstant.advanced(
            by: .milliseconds(100)
        )
        await clock.resumeNext(at: restartWakeInstant)
        let didRecordRequest = await eventually {
            await target.requestCount() == 1
        }
        driver.stop()
        await clock.resumeAll()

        #expect(didRecordRequest)
        #expect(await target.requestCount() == 1)
    }

    @Test func cursorMismatchFaultsUntilTheAppSynchronizes() async throws {
        let initialCursor = makeCursor()
        let rebuiltCursor = makeCursor(
            sessionID: SimulationSessionID(),
            tick: .zero
        )
        let target = RecordingAdvanceTarget(
            cursor: initialCursor,
            mismatchCursors: [rebuiltCursor]
        )
        let inputSource = SequencedInputSource(snapshots: [.empty])
        let baseInstant = SuspendingClock().now
        let clock = TestRealtimeClock(
            initialInstant: baseInstant,
            suspension: .immediate(
                wakes: [
                    (
                        instant: baseInstant.advanced(by: .milliseconds(100)),
                        result: .success(())
                    ),
                    (
                        instant: baseInstant.advanced(by: .milliseconds(200)),
                        result: .success(())
                    ),
                    (
                        instant: baseInstant.advanced(by: .milliseconds(200)),
                        result: .failure(CancellationError())
                    )
                ]
            )
        )
        let driver = makeDriver(
            target: target,
            inputSource: inputSource,
            cursor: initialCursor,
            fixedTimeStep: .milliseconds(100),
            pollInterval: .milliseconds(100),
            clock: clock
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
        let clock = TestRealtimeClock(
            initialInstant: baseInstant,
            suspension: .controlled
        )
        let driver = makeSuspendedDriver(
            target: target,
            cursor: initialCursor,
            clock: clock
        )

        driver.start()
        await clock.waitForPendingCount(1)
        let firstWakeInstant = baseInstant.advanced(by: .milliseconds(100))
        await clock.resumeNext(at: firstWakeInstant)
        await target.waitForRequestCount(1)

        driver.stop()
        driver.start()

        #expect(driver.isRunning)
        let firstDeadline = baseInstant.advanced(by: .milliseconds(100))
        #expect(await clock.recordedDeadlines() == [firstDeadline])

        let firstRequest = try #require(await target.recordedRequests().first)
        let firstOutcome = completedOutcome(
            for: firstRequest,
            from: initialCursor
        )
        let firstFinalCursor = try completedCursor(from: firstOutcome)
        let restartInstant = baseInstant.advanced(by: .seconds(10))
        await clock.setCurrentInstant(restartInstant)
        await target.resumeNext(with: firstOutcome)

        await clock.waitForPendingCount(1)
        let restartDeadline = restartInstant.advanced(
            by: .milliseconds(100)
        )
        #expect(
            await clock.recordedDeadlines()
                == [firstDeadline, restartDeadline]
        )
        await clock.resumeNext(at: restartDeadline)
        await target.waitForRequestCount(2)

        let secondRequest = try #require(await target.recordedRequests().last)
        #expect(secondRequest.expectedCursor == firstFinalCursor)
        #expect(secondRequest.stepCount.rawValue == 1)

        driver.stop()
        await target.resumeNext(
            with: completedOutcome(
                for: secondRequest,
                from: firstFinalCursor
            )
        )
        await clock.resumeAll()
    }

    @Test func stopAndDrainWaitsForAnAlreadyIssuedRequest() async throws {
        let initialCursor = makeCursor()
        let target = SuspendedAdvanceTarget()
        let baseInstant = SuspendingClock().now
        let clock = TestRealtimeClock(
            initialInstant: baseInstant,
            suspension: .controlled
        )
        let driver = makeSuspendedDriver(
            target: target,
            cursor: initialCursor,
            clock: clock
        )

        driver.start()
        await clock.waitForPendingCount(1)
        let firstWakeInstant = baseInstant.advanced(by: .milliseconds(100))
        await clock.resumeNext(at: firstWakeInstant)
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
        await clock.resumeAll()
    }

    @Test func explicitSynchronizationSupersedesRetiringOldSessionResult() async throws {
        let initialCursor = makeCursor()
        let synchronizedCursor = makeCursor(sessionID: SimulationSessionID())
        let target = SuspendedAdvanceTarget()
        let baseInstant = SuspendingClock().now
        let clock = TestRealtimeClock(
            initialInstant: baseInstant,
            suspension: .controlled
        )
        let driver = makeSuspendedDriver(
            target: target,
            cursor: initialCursor,
            clock: clock
        )

        driver.start()
        await clock.waitForPendingCount(1)
        let firstWakeInstant = baseInstant.advanced(by: .milliseconds(100))
        await clock.resumeNext(at: firstWakeInstant)
        await target.waitForRequestCount(1)

        driver.stop()
        driver.synchronize(to: synchronizedCursor, inputBaseline: nil)
        driver.start()

        let firstRequest = try #require(await target.recordedRequests().first)
        let restartInstant = baseInstant.advanced(by: .seconds(10))
        await clock.setCurrentInstant(restartInstant)
        await target.resumeNext(
            with: completedOutcome(
                for: firstRequest,
                from: initialCursor
            )
        )

        await clock.waitForPendingCount(1)
        let restartWakeInstant = restartInstant.advanced(
            by: .milliseconds(100)
        )
        await clock.resumeNext(at: restartWakeInstant)
        await target.waitForRequestCount(2)

        let secondRequest = try #require(await target.recordedRequests().last)
        #expect(secondRequest.expectedCursor == synchronizedCursor)
        #expect(secondRequest.stepCount.rawValue == 1)

        driver.stop()
        await target.resumeNext(
            with: completedOutcome(
                for: secondRequest,
                from: synchronizedCursor
            )
        )
        await clock.resumeAll()
    }

    private func makeDriver(
        target: RecordingAdvanceTarget,
        inputSource: (any PInputSnapshotSource)?,
        cursor: SimulationCursor,
        fixedTimeStep: Duration,
        pollInterval: Duration,
        clock: any PRealtimeClock
    ) -> RealtimeAdvanceDriver {
        RealtimeAdvanceDriver(
            advanceTarget: target,
            inputSource: inputSource,
            initialCursor: cursor,
            fixedTimeStep: fixedTimeStep,
            pollInterval: pollInterval,
            catchUpPolicy: .interactive,
            isAdvancementEnabled: true,
            clock: clock
        )
    }

    private func makeSuspendedDriver(
        target: SuspendedAdvanceTarget,
        cursor: SimulationCursor,
        clock: any PRealtimeClock
    ) -> RealtimeAdvanceDriver {
        RealtimeAdvanceDriver(
            advanceTarget: target,
            inputSource: nil,
            initialCursor: cursor,
            fixedTimeStep: .milliseconds(100),
            pollInterval: .milliseconds(100),
            catchUpPolicy: .interactive,
            isAdvancementEnabled: true,
            clock: clock
        )
    }

    private func completedOutcome(
        for request: SimulationAdvanceRequest,
        from initialCursor: SimulationCursor
    ) -> SimulationAdvanceOutcome {
        let finalCursor = SimulationCursor(
            sessionID: initialCursor.sessionID,
            tick: SimulationTick(
                rawValue: initialCursor.tick.rawValue + UInt64(request.stepCount.rawValue)
            )
        )
        let finalPresentationSnapshot = SimulationPresentationSnapshot(
            cursor: finalCursor,
            camera: .standard,
            entityPresentations: []
        )

        return .completed(
            SimulationAdvanceResult(
                initialCursor: initialCursor,
                finalCursor: finalCursor,
                completedStepCount: SimulationCompletedStepCount(
                    rawValue: request.stepCount.rawValue
                ),
                finalPresentationSnapshot: finalPresentationSnapshot
            )
        )
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

    nonisolated private final class TestRealtimeClock: PRealtimeClock, @unchecked Sendable {
        typealias ImmediateWake = (
            instant: SuspendingClock.Instant,
            result: Result<Void, any Error>
        )

        enum Suspension {
            case immediate(wakes: [ImmediateWake])
            case controlled
        }

        private struct Waiter {
            let deadline: SuspendingClock.Instant
            let continuation: CheckedContinuation<Void, any Error>
        }

        private let lock = NSLock()
        private let suspension: Suspension
        private var currentInstant: SuspendingClock.Instant
        private var nextImmediateWakeIndex = 0
        private var deadlines: [SuspendingClock.Instant] = []
        private var waiters: [Waiter] = []
        private var countWaiters: [
            Int: [CheckedContinuation<Void, Never>]
        ] = [:]

        var now: SuspendingClock.Instant {
            lock.withLock {
                currentInstant
            }
        }

        init(
            initialInstant: SuspendingClock.Instant,
            suspension: Suspension
        ) {
            if case let .immediate(wakes) = suspension {
                precondition(
                    wakes.isEmpty == false,
                    "An immediate test clock requires at least one wake."
                )
            }

            self.currentInstant = initialInstant
            self.suspension = suspension
        }

        func sleep(until deadline: SuspendingClock.Instant) async throws {
            switch suspension {
            case let .immediate(wakes):
                let wake = lock.withLock {
                    deadlines.append(deadline)
                    let index = min(
                        nextImmediateWakeIndex,
                        wakes.count - 1
                    )
                    nextImmediateWakeIndex += 1
                    let wake = wakes[index]
                    precondition(
                        wake.instant >= currentInstant,
                        "A conforming test clock cannot move backward."
                    )
                    if case .success = wake.result {
                        precondition(
                            wake.instant >= deadline,
                            "A successful test sleep cannot resume before its deadline."
                        )
                    }
                    currentInstant = wake.instant
                    return wake
                }
                try wake.result.get()

            case .controlled:
                try await withCheckedThrowingContinuation { continuation in
                    let waiter = Waiter(
                        deadline: deadline,
                        continuation: continuation
                    )
                    let satisfiedWaiters = lock.withLock {
                        deadlines.append(deadline)
                        waiters.append(waiter)
                        return removeSatisfiedCountWaitersLocked()
                    }
                    for satisfiedWaiter in satisfiedWaiters {
                        satisfiedWaiter.resume()
                    }
                }
            }
        }

        func waitForPendingCount(_ count: Int) async {
            await withCheckedContinuation { continuation in
                let isAlreadySatisfied = lock.withLock {
                    guard waiters.count < count else {
                        return true
                    }

                    countWaiters[count, default: []].append(continuation)
                    return false
                }
                if isAlreadySatisfied {
                    continuation.resume()
                }
            }
        }

        func resumeNext(at instant: SuspendingClock.Instant) async {
            let waiter: Waiter? = lock.withLock {
                guard let waiter = waiters.first else {
                    return nil
                }

                precondition(
                    instant >= currentInstant,
                    "A conforming test clock cannot move backward."
                )
                precondition(
                    instant >= waiter.deadline,
                    "A successful test sleep cannot resume before its deadline."
                )
                currentInstant = instant
                return waiters.removeFirst()
            }
            guard let waiter else {
                Issue.record("No controlled sleep was pending.")
                return
            }

            waiter.continuation.resume()
        }

        func setCurrentInstant(_ instant: SuspendingClock.Instant) async {
            lock.withLock {
                precondition(
                    instant >= currentInstant,
                    "A conforming test clock cannot move backward."
                )
                currentInstant = instant
            }
        }

        func resumeAll() async {
            let pendingWaiters = lock.withLock {
                let pendingWaiters = waiters
                waiters.removeAll()
                return pendingWaiters
            }
            for waiter in pendingWaiters {
                waiter.continuation.resume(throwing: CancellationError())
            }
        }

        func recordedDeadlines() async -> [SuspendingClock.Instant] {
            lock.withLock {
                deadlines
            }
        }

        private func removeSatisfiedCountWaitersLocked() -> [
            CheckedContinuation<Void, Never>
        ] {
            let satisfiedCounts = countWaiters.keys.filter {
                $0 <= waiters.count
            }
            var satisfiedWaiters: [
                CheckedContinuation<Void, Never>
            ] = []
            for count in satisfiedCounts {
                let continuations = countWaiters.removeValue(forKey: count) ?? []
                satisfiedWaiters.append(contentsOf: continuations)
            }
            return satisfiedWaiters
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
            let finalCursor = SimulationCursor(
                sessionID: cursor.sessionID,
                tick: SimulationTick(
                    rawValue: cursor.tick.rawValue + UInt64(request.stepCount.rawValue)
                )
            )
            cursor = finalCursor
            let finalPresentationSnapshot = SimulationPresentationSnapshot(
                cursor: finalCursor,
                camera: .standard,
                entityPresentations: []
            )

            return .completed(
                SimulationAdvanceResult(
                    initialCursor: initialCursor,
                    finalCursor: finalCursor,
                    completedStepCount: SimulationCompletedStepCount(
                        rawValue: request.stepCount.rawValue
                    ),
                    finalPresentationSnapshot: finalPresentationSnapshot
                )
            )
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

    /// Deliberately violates the clock contract to verify defensive elapsed-time clamping.
    private final class NonmonotonicTestClock: PRealtimeClock {
        typealias Wake = (
            instant: SuspendingClock.Instant,
            result: Result<Void, any Error>
        )

        private var currentInstant: SuspendingClock.Instant
        private var wakes: [Wake]

        var now: SuspendingClock.Instant {
            currentInstant
        }

        init(
            initialInstant: SuspendingClock.Instant,
            wakes: [Wake]
        ) {
            precondition(wakes.isEmpty == false)
            self.currentInstant = initialInstant
            self.wakes = wakes
        }

        func sleep(until _: SuspendingClock.Instant) async throws {
            let wake = wakes.removeFirst()
            currentInstant = wake.instant
            try wake.result.get()
        }
    }
}
