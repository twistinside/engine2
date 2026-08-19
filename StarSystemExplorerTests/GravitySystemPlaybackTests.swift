import Foundation
import Testing

@testable import StarSystemExplorer

nonisolated struct GravitySystemPlaybackTests {
    private let referenceDate = Date(timeIntervalSinceReferenceDate: 1_000)

    @Test func absoluteTimelineDatesDeterminePlaybackInsteadOfTickCount() throws {
        var playback = GravitySystemPlayback(rate: .dayPerSecond)
        playback.start(from: 100, at: referenceDate, upperBound: 1_000_000)

        let halfSecondProjection = playback.advance(
            to: referenceDate.addingTimeInterval(0.5),
            upperBound: 1_000_000
        )
        let halfSecond = try #require(halfSecondProjection)
        let oneAndAHalfSecondProjection = playback.advance(
            to: referenceDate.addingTimeInterval(1.5),
            upperBound: 1_000_000
        )
        let oneAndAHalfSeconds = try #require(oneAndAHalfSecondProjection)

        #expect(halfSecond == 43_300)
        #expect(oneAndAHalfSeconds == 129_700)
    }

    @Test func playbackStopsAtTheCurrentEpochBound() throws {
        var playback = GravitySystemPlayback(rate: .dayPerSecond)
        playback.start(from: 900, at: referenceDate, upperBound: 1_000)

        let endpointProjection = playback.advance(
            to: referenceDate.addingTimeInterval(1),
            upperBound: 1_000
        )
        let endpoint = try #require(endpointProjection)

        #expect(endpoint == 1_000)
        #expect(!playback.isPlaying)
        #expect(
            playback.advance(
                to: referenceDate.addingTimeInterval(2),
                upperBound: 1_000
            ) == nil
        )
    }

    @Test func pauseProjectsThroughTheExactPauseDateAndStopsFutureAdvancement() {
        var playback = GravitySystemPlayback(rate: .dayPerSecond)
        playback.start(from: 100, at: referenceDate, upperBound: 1_000_000)

        let pausedElapsedSeconds = playback.pause(
            at: referenceDate.addingTimeInterval(0.5),
            upperBound: 1_000_000
        )

        #expect(pausedElapsedSeconds == 43_300)
        #expect(!playback.isPlaying)
        #expect(
            playback.advance(
                to: referenceDate.addingTimeInterval(1),
                upperBound: 1_000_000
            ) == nil
        )
    }

    @Test func startingAtTheEpochBoundRemainsStopped() {
        var playback = GravitySystemPlayback(rate: .dayPerSecond)

        playback.start(from: 1_000, at: referenceDate, upperBound: 1_000)

        #expect(!playback.isPlaying)
        #expect(
            playback.advance(
                to: referenceDate.addingTimeInterval(1),
                upperBound: 1_000
            ) == nil
        )
    }

    @Test func manualScrubbingAndRateSelectionReanchorActivePlayback() throws {
        var playback = GravitySystemPlayback(rate: .dayPerSecond)
        playback.start(from: 0, at: referenceDate, upperBound: 2_000_000)
        _ = playback.advance(
            to: referenceDate.addingTimeInterval(1),
            upperBound: 2_000_000
        )

        playback.synchronize(
            to: 500,
            at: referenceDate.addingTimeInterval(1),
            upperBound: 2_000_000
        )
        let afterScrubProjection = playback.advance(
            to: referenceDate.addingTimeInterval(2),
            upperBound: 2_000_000
        )
        let afterScrub = try #require(afterScrubProjection)
        playback.selectRate(
            .thirtyDaysPerSecond,
            from: afterScrub,
            at: referenceDate.addingTimeInterval(2),
            upperBound: 2_000_000
        )
        let afterRateChangeProjection = playback.advance(
            to: referenceDate.addingTimeInterval(2.5),
            upperBound: 2_000_000
        )
        let afterRateChange = try #require(afterRateChangeProjection)

        #expect(afterScrub == 86_900)
        #expect(afterRateChange == 1_382_900)
        #expect(playback.isPlaying)
    }
}
