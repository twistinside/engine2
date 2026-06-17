//
//  Clock.swift
//  Engine2
//
//  Created by Karl Groff on 3/11/26.
//


/// Reports real elapsed time to the engine without owning simulation policy.
///
/// The clock's job is only to answer "how much wall-clock time passed since the
/// last sample?" Fixed-step accumulation, catch-up behavior, and system
/// scheduling still belong in `Engine`.
protocol Clock {
    /// Returns the elapsed real time since the last clock sample.
    mutating func consumeDeltaTime() -> Duration
}
