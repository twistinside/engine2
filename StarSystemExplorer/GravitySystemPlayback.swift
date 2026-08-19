import Foundation

/// Maps wall-clock display time onto the explorer's bounded displayed epoch.
///
/// The value owns playback controls and an absolute display-time anchor. It does
/// not evaluate gravity, advance Simulation, or own celestial state.
nonisolated struct GravitySystemPlayback: Sendable {
    private(set) var isPlaying = false
    private(set) var rate: GravitySystemPlaybackRate

    private var anchorDate: Date?
    private var anchorElapsedSeconds = 0.0

    init(rate: GravitySystemPlaybackRate = .yearPerSecond) {
        self.rate = rate
    }

    /// Starts playback from the supplied displayed epoch when more range remains.
    mutating func start(
        from elapsedSeconds: Double,
        at date: Date,
        upperBound: Double
    ) {
        synchronize(to: elapsedSeconds, at: date, upperBound: upperBound)
        isPlaying = anchorElapsedSeconds < normalizedUpperBound(upperBound)
    }

    /// Stops playback and returns the displayed epoch projected through the pause time.
    mutating func pause(at date: Date, upperBound: Double) -> Double {
        let elapsedSeconds = projectedElapsedSeconds(at: date, upperBound: upperBound)
            ?? clampedElapsedSeconds(anchorElapsedSeconds, upperBound: upperBound)
        isPlaying = false
        anchorDate = date
        anchorElapsedSeconds = elapsedSeconds
        return elapsedSeconds
    }

    /// Returns the displayed epoch for one timeline date and stops at the current bound.
    mutating func advance(to date: Date, upperBound: Double) -> Double? {
        guard let elapsedSeconds = projectedElapsedSeconds(at: date, upperBound: upperBound) else {
            return nil
        }
        if elapsedSeconds >= normalizedUpperBound(upperBound) {
            isPlaying = false
            anchorDate = date
            anchorElapsedSeconds = elapsedSeconds
        }
        return elapsedSeconds
    }

    /// Reanchors active playback after the caller changes the displayed epoch directly.
    mutating func synchronize(
        to elapsedSeconds: Double,
        at date: Date,
        upperBound: Double
    ) {
        anchorDate = date
        anchorElapsedSeconds = clampedElapsedSeconds(
            elapsedSeconds,
            upperBound: upperBound
        )
        if anchorElapsedSeconds >= normalizedUpperBound(upperBound) {
            isPlaying = false
        }
    }

    /// Changes rate without introducing an epoch jump at the selection time.
    mutating func selectRate(
        _ rate: GravitySystemPlaybackRate,
        from elapsedSeconds: Double,
        at date: Date,
        upperBound: Double
    ) {
        synchronize(to: elapsedSeconds, at: date, upperBound: upperBound)
        self.rate = rate
    }

    private func projectedElapsedSeconds(
        at date: Date,
        upperBound: Double
    ) -> Double? {
        guard isPlaying, let anchorDate else {
            return nil
        }
        let wallTimeSeconds = max(date.timeIntervalSince(anchorDate), 0)
        return clampedElapsedSeconds(
            anchorElapsedSeconds + wallTimeSeconds * rate.rawValue,
            upperBound: upperBound
        )
    }

    private func clampedElapsedSeconds(
        _ elapsedSeconds: Double,
        upperBound: Double
    ) -> Double {
        min(max(elapsedSeconds, 0), normalizedUpperBound(upperBound))
    }

    private func normalizedUpperBound(_ upperBound: Double) -> Double {
        max(upperBound, 0)
    }
}
