import Foundation

/// Selects the distance projection used by the orbital architecture diagram.
nonisolated enum StarSystemOrbitScale: String, CaseIterable, Identifiable, Sendable {
    case linear
    case logarithmic

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .linear: "Linear"
        case .logarithmic: "Logarithmic"
        }
    }

    func position(for value: Double, in range: ClosedRange<Double>) -> Double {
        validate(range)

        switch self {
        case .linear:
            let clamped = min(max(value, range.lowerBound), range.upperBound)
            return (clamped - range.lowerBound) / (range.upperBound - range.lowerBound)
        case .logarithmic:
            return LogarithmicOrbitScale(
                lowerBound: range.lowerBound,
                upperBound: range.upperBound
            )
            .position(for: value)
        }
    }

    func tickValues(in range: ClosedRange<Double>) -> [Double] {
        validate(range)

        let intervalCount = 4
        switch self {
        case .linear:
            let interval = (range.upperBound - range.lowerBound) / Double(intervalCount)
            return (0...intervalCount).map { range.lowerBound + Double($0) * interval }
        case .logarithmic:
            let logarithmicScale = LogarithmicOrbitScale(
                lowerBound: range.lowerBound,
                upperBound: range.upperBound
            )
            return (0...intervalCount).map {
                logarithmicScale.value(at: Double($0) / Double(intervalCount))
            }
        }
    }

    private func validate(_ range: ClosedRange<Double>) {
        precondition(
            range.lowerBound.isFinite && range.lowerBound >= 0,
            "The lower orbital scale bound must be finite and nonnegative."
        )
        precondition(
            range.upperBound.isFinite && range.upperBound > range.lowerBound,
            "The upper orbital scale bound must be finite and greater than the lower bound."
        )
    }
}
