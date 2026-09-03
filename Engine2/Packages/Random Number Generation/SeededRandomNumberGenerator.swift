protocol SeededRandomNumberGenerator: RandomNumberGenerator {
    var seed: UInt64 { get }
}
