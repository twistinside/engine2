import Foundation
import Testing
@testable import Engine2

struct RealtimeAdvanceDriverTests {
    @Test @MainActor func substepElapsedTimeAccumulatesUntilOneExactStepIsReady() async {
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
        let sleeper = ImmediateSleeper(
            results: [
                .success(()),
                .success(()),
                .success(()),
                .failure(CancellationError())
            ]
        )
        let driver = makeDriver(
            target: target,
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

    @Test @MainActor func oneWakeCanRequestMultipleStepsAndCarryItsRemainder() async {
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
        let sleeper = ImmediateSleeper(
            results: [.success(()), .success(()), .failure(CancellationError())]
        )
        let driver = makeDriver(
            target: target,
            cursor: cursor,
            fixedTimeStep: .milliseconds(100),
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
        #expect(didRecordRequests)
        #expect(requests.map(\.stepCount.rawValue) == [2, 1])
        #expect(requests[0].expectedCursor == cursor)
        #expect(requests[1].expectedCursor?.tick == SimulationTick(rawValue: 2))
    }

    @Test @MainActor func preservePolicyCapsOneWakeThenDrainsBacklog() async {
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
        let sleeper = ImmediateSleeper(
            results: [.success(()), .success(()), .failure(CancellationError())]
        )
        let driver = RealtimeAdvanceDriver(
            advanceTarget: target,
            initialCursor: cursor,
            fixedTimeStep: .milliseconds(100),
            pollInterval: .milliseconds(100),
            catchUpPolicy: RealtimeCatchUpPolicy(
                maximumStepsPerWake: SimulationStepCount(rawValue: 3),
                backlogTreatment: .preserve
            ),
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

    @Test @MainActor func discardPolicyDropsOnlyOverflowingWholeStepDebt() async {
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
        let sleeper = ImmediateSleeper(
            results: [.success(()), .success(()), .failure(CancellationError())]
        )
        let driver = RealtimeAdvanceDriver(
            advanceTarget: target,
            initialCursor: cursor,
            fixedTimeStep: .milliseconds(100),
            pollInterval: .milliseconds(100),
            catchUpPolicy: RealtimeCatchUpPolicy(
                maximumStepsPerWake: SimulationStepCount(rawValue: 3),
                backlogTreatment: .discardOverflow
            ),
            clockFactory: { SystemClock(timeSource: elapsedSource.next) },
            scheduleTimeSource: { baseInstant },
            sleeper: sleeper.sleep(until:)
        )

        driver.start()
        let didStop = await eventually { driver.isRunning == false }

        #expect(didStop)
        #expect(await target.recordedRequests().map(\.stepCount.rawValue) == [3])
    }

    @Test @MainActor func discardPolicyRetainsFractionWhenNoWholeStepOverflows() async {
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
        let sleeper = ImmediateSleeper(
            results: [.success(()), .success(()), .failure(CancellationError())]
        )
        let driver = RealtimeAdvanceDriver(
            advanceTarget: target,
            initialCursor: cursor,
            fixedTimeStep: .milliseconds(100),
            pollInterval: .milliseconds(100),
            catchUpPolicy: RealtimeCatchUpPolicy(
                maximumStepsPerWake: SimulationStepCount(rawValue: 3),
                backlogTreatment: .discardOverflow
            ),
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

    @Test @MainActor func startBaselinePreservesInputPublishedBeforeFirstTick() async throws {
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
        let elapsedSource = SampledInstantSource(
            samples: [baseInstant, baseInstant.advanced(by: .milliseconds(100))]
        )
        let sleeper = ImmediateSleeper(
            results: [.success(()), .failure(CancellationError())]
        )
        let driver = makeDriver(
            target: target,
            inputSource: inputSource,
            cursor: cursor,
            fixedTimeStep: .milliseconds(100),
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

    @Test @MainActor func pauseDiscardsBacklogAndResumeRebasesInput() async throws {
        let cursor = makeCursor()
        let target = RecordingAdvanceTarget(cursor: cursor)
        let inputSource = SequencedInputSource(
            snapshots: [
                inputSnapshot(
                    revision: InputRevision(session: 2, sequence: 1),
                    pointerMotionTotal: SIMD2<Float>(6, 0)
                ),
                inputSnapshot(
                    revision: InputRevision(session: 2, sequence: 2),
                    pointerMotionTotal: SIMD2<Float>(10, 0)
                ),
                inputSnapshot(
                    revision: InputRevision(session: 2, sequence: 3),
                    pointerMotionTotal: SIMD2<Float>(12, 0)
                )
            ]
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
        await sleeper.resumeNext()
        await sleeper.waitForPendingCount(1)
        #expect(await target.requestCount() == 0)

        driver.resumeAdvancement()
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
        #expect(baseline.pointerMotionTotal == SIMD2<Float>(10, 0))
        #expect(snapshot.pointerMotionTotal == SIMD2<Float>(12, 0))
    }

    @Test @MainActor func startAndStopAreIdempotentAndPreservePausePreference() async {
        let cursor = makeCursor()
        let target = RecordingAdvanceTarget(cursor: cursor)
        let sleeper = ControlledSleeper()
        var clockCreationCount = 0
        let driver = RealtimeAdvanceDriver(
            advanceTarget: target,
            initialCursor: cursor,
            fixedTimeStep: .seconds(1),
            pollInterval: .seconds(1),
            isAdvancementEnabled: false,
            clockFactory: {
                clockCreationCount += 1
                return SystemClock()
            },
            sleeper: sleeper.sleep(until:)
        )

        driver.start()
        driver.start()
        await sleeper.waitForPendingCount(1)

        #expect(driver.isRunning)
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

    @Test @MainActor func suspendedPollingTaskDoesNotRetainTheDriver() async {
        let cursor = makeCursor()
        let target = RecordingAdvanceTarget(cursor: cursor)
        let sleeper = ControlledSleeper()
        var driver: RealtimeAdvanceDriver? = RealtimeAdvanceDriver(
            advanceTarget: target,
            initialCursor: cursor,
            fixedTimeStep: .seconds(1),
            pollInterval: .seconds(1),
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

    @Test @MainActor func enabledStopAndRestartRebasesTheNextInputRequest() async throws {
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

    @Test @MainActor func pollingUsesAbsoluteDeadlinesAfterOversleep() async {
        let cursor = makeCursor()
        let target = RecordingAdvanceTarget(cursor: cursor)
        let baseInstant = SuspendingClock().now
        let elapsedSource = SampledInstantSource(
            samples: [baseInstant, baseInstant.advanced(by: .milliseconds(110))]
        )
        let scheduleSource = SampledInstantSource(
            samples: [baseInstant, baseInstant.advanced(by: .milliseconds(110))]
        )
        let sleeper = ImmediateSleeper(
            results: [.success(()), .failure(CancellationError())]
        )
        let driver = RealtimeAdvanceDriver(
            advanceTarget: target,
            initialCursor: cursor,
            fixedTimeStep: .milliseconds(100),
            pollInterval: .milliseconds(100),
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

    @Test @MainActor func staleWakeAfterStopAndRestartCannotRequestAnAdvance() async {
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
            cursor: cursor,
            fixedTimeStep: .milliseconds(100),
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

    @Test @MainActor func cursorMismatchFaultsUntilTheAppSynchronizes() async throws {
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
        let firstElapsedSource = SampledInstantSource(
            samples: [baseInstant, baseInstant.advanced(by: .milliseconds(100))]
        )
        let secondElapsedSource = SampledInstantSource(
            samples: [baseInstant, baseInstant.advanced(by: .milliseconds(100))]
        )
        var clockCreationCount = 0
        let sleeper = ImmediateSleeper(
            results: [.success(()), .success(()), .failure(CancellationError())]
        )
        let driver = makeDriver(
            target: target,
            inputSource: inputSource,
            cursor: initialCursor,
            fixedTimeStep: .milliseconds(100),
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
            driver.fault == .cursorMismatch(
                expected: initialCursor,
                current: rebuiltCursor
            )
        )

        driver.resumeAdvancement()
        #expect(driver.isAdvancementEnabled == false)

        driver.synchronize(to: rebuiltCursor)
        driver.resumeAdvancement()
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

    @Test @MainActor func retiringCompletionUpdatesCursorBeforeQueuedRestart() async throws {
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

    @Test @MainActor func stopAndDrainWaitsForAnAlreadyIssuedRequest() async throws {
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

        let drainTask = Task { @MainActor in
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

    @Test @MainActor func explicitSynchronizationSupersedesRetiringOldSessionResult() async throws {
        let initialCursor = makeCursor()
        let synchronizedCursor = makeCursor(sessionID: SimulationSessionID())
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
        driver.synchronize(to: synchronizedCursor)
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

    @MainActor
    private func makeDriver(
        target: RecordingAdvanceTarget,
        inputSource: (any PInputSnapshotSource)? = nil,
        cursor: SimulationCursor,
        fixedTimeStep: Duration,
        pollInterval: Duration? = nil,
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
            clockFactory: clockFactory,
            scheduleTimeSource: { baseInstant },
            sleeper: sleeper
        )
    }

    @MainActor
    private func makeSuspendedDriver(
        target: SuspendedAdvanceTarget,
        cursor: SimulationCursor,
        baseInstant: SuspendingClock.Instant,
        clockFactory: @escaping RealtimeAdvanceDriver.ClockFactory,
        sleeper: @escaping RealtimeAdvanceDriver.Sleeper
    ) -> RealtimeAdvanceDriver {
        RealtimeAdvanceDriver(
            advanceTarget: target,
            initialCursor: cursor,
            fixedTimeStep: .milliseconds(100),
            pollInterval: .milliseconds(100),
            clockFactory: clockFactory,
            scheduleTimeSource: { baseInstant },
            sleeper: sleeper
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

        return .completed(
            SimulationAdvanceResult(
                initialCursor: initialCursor,
                finalCursor: finalCursor,
                completedStepCount: SimulationCompletedStepCount(
                    rawValue: request.stepCount.rawValue
                ),
                finalPresentationSnapshot: SimulationPresentationSnapshot(
                    cursor: finalCursor,
                    camera: Camera(),
                    entityPresentations: []
                )
            )
        )
    }

    private func completedCursor(
        from outcome: SimulationAdvanceOutcome
    ) throws -> SimulationCursor {
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

    private func inputSnapshot(
        revision: InputRevision,
        pointerMotionTotal: SIMD2<Float>
    ) -> InputSnapshot {
        InputSnapshot(
            revision: revision,
            pointerPosition: pointerMotionTotal,
            pointerMotionTotal: pointerMotionTotal,
            scrollTotal: .zero,
            pressedMouseButtons: [],
            pressedKeys: []
        )
    }

    @MainActor
    private func eventually(
        _ condition: () async -> Bool
    ) async -> Bool {
        for _ in 0..<10_000 {
            if await condition() {
                return true
            }
            await Task.yield()
        }

        return false
    }
}

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

    func sleep(until deadline: SuspendingClock.Instant) async throws {
        try await withCheckedThrowingContinuation { continuation in
            waiters.append(Waiter(continuation: continuation))
        }
    }

    func waitForPendingCount(_ count: Int) async {
        for _ in 0..<10_000 {
            if waiters.count >= count {
                return
            }
            await Task.yield()
        }

        Issue.record("Timed out waiting for \(count) controlled sleeps.")
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
}

private actor RecordingAdvanceTarget: PSimulationAdvanceTarget {
    private var cursor: SimulationCursor
    private var requests: [SimulationAdvanceRequest] = []
    private var mismatchCursors: [SimulationCursor]

    init(
        cursor: SimulationCursor,
        mismatchCursors: [SimulationCursor] = []
    ) {
        self.cursor = cursor
        self.mismatchCursors = mismatchCursors
    }

    func advance(
        _ request: SimulationAdvanceRequest
    ) async -> SimulationAdvanceOutcome {
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

        return .completed(
            SimulationAdvanceResult(
                initialCursor: initialCursor,
                finalCursor: finalCursor,
                completedStepCount: SimulationCompletedStepCount(
                    rawValue: request.stepCount.rawValue
                ),
                finalPresentationSnapshot: SimulationPresentationSnapshot(
                    cursor: finalCursor,
                    camera: Camera(),
                    entityPresentations: []
                )
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

    func advance(
        _ request: SimulationAdvanceRequest
    ) async -> SimulationAdvanceOutcome {
        requests.append(request)

        return await withCheckedContinuation { continuation in
            pendingAdvances.append(PendingAdvance(continuation: continuation))
        }
    }

    func waitForRequestCount(_ count: Int) async {
        for _ in 0..<10_000 {
            if requests.count >= count {
                return
            }
            await Task.yield()
        }

        Issue.record("Timed out waiting for \(count) suspended advances.")
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
}

@MainActor
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
