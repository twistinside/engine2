//
//  ManualClock.swift
//  Engine2
//
//  Created by Karl Groff on 3/8/26.
//

/// Deterministic test clock that only advances when the caller says so.
struct ManualClock: Clock {
    private(set) var currentTime: Duration = .zero
    private var lastSample: Duration = .zero

    /// Moves the clock forward by a controlled amount for tests or scripted stepping.
    mutating func advance(by deltaTime: Duration) {
        precondition(deltaTime >= .zero, "ManualClock cannot advance backwards")
        currentTime += deltaTime
    }

    /// Returns the controlled elapsed time since the previous sample.
    mutating func consumeDeltaTime() -> Duration {
        let deltaTime = currentTime - lastSample
        lastSample = currentTime
        return deltaTime
    }
}
