//
//  SystemClock.swift
//  Engine2
//
//  Created by Karl Groff on 3/11/26.
//


import Foundation

/// Monotonic engine clock backed by `SuspendingClock`.
///
/// `SuspendingClock` is monotonic and pauses while the machine is suspended, so
/// simulation time does not try to "catch up" after sleep. Wrapping it here
/// keeps the engine on a simple synchronous polling API.
struct SystemClock: Clock {
    typealias Instant = SuspendingClock.Instant
    typealias TimeSource = () -> Instant

    private let timeSource: TimeSource
    private var lastSample: Instant

    init(timeSource: @escaping TimeSource = { SuspendingClock().now }) {
        let initialSample = timeSource()
        self.timeSource = timeSource
        self.lastSample = initialSample
    }

    /// Samples the current instant and returns the elapsed duration since the
    /// previous sample. Any backward jump from an injected test source is
    /// clamped so the engine never steps backwards in time.
    mutating func consumeDeltaTime() -> Duration {
        let currentSample = timeSource()
        let deltaTime = lastSample.duration(to: currentSample)
        lastSample = currentSample
        return max(.zero, deltaTime)
    }
}
