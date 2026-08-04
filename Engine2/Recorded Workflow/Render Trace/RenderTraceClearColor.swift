/// Finite backend-neutral clear color retained with one recorded Render frame.
///
/// Components remain unclamped because a Render target may deliberately accept
/// values outside the normalized display interval.
nonisolated struct RenderTraceClearColor: Codable, Equatable, Sendable {
    static let opaqueBlack = RenderTraceClearColor(
        validatedRed: 0,
        green: 0,
        blue: 0,
        alpha: 1
    )

    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    /// Constructs a clear color whose four components are finite.
    init(
        red: Double,
        green: Double,
        blue: Double,
        alpha: Double
    ) throws(RenderTraceValidationError) {
        guard red.isFinite,
              green.isFinite,
              blue.isFinite,
              alpha.isFinite else {
            throw .invalidClearColor
        }

        self.init(
            validatedRed: red,
            green: green,
            blue: blue,
            alpha: alpha
        )
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            red: container.decode(Double.self, forKey: .red),
            green: container.decode(Double.self, forKey: .green),
            blue: container.decode(Double.self, forKey: .blue),
            alpha: container.decode(Double.self, forKey: .alpha)
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(red, forKey: .red)
        try container.encode(green, forKey: .green)
        try container.encode(blue, forKey: .blue)
        try container.encode(alpha, forKey: .alpha)
    }

    private init(
        validatedRed red: Double,
        green: Double,
        blue: Double,
        alpha: Double
    ) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    private enum CodingKeys: String, CodingKey {
        case red
        case green
        case blue
        case alpha
    }
}
