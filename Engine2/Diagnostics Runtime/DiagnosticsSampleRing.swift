/// Fixed-capacity insertion-ordered storage for recent diagnostic samples.
struct DiagnosticsSampleRing {
    let capacity: Int

    private var storage: [DiagnosticsSample?]
    private var nextWriteIndex = 0
    private(set) var count = 0

    init(capacity: Int) {
        precondition(capacity > 0, "Diagnostics sample capacity must be positive")
        self.capacity = capacity
        self.storage = Array(repeating: nil, count: capacity)
    }

    mutating func append(_ sample: DiagnosticsSample) {
        storage[nextWriteIndex] = sample
        nextWriteIndex = (nextWriteIndex + 1) % capacity
        count = min(count + 1, capacity)
    }

    mutating func removeAll() {
        storage = Array(repeating: nil, count: capacity)
        nextWriteIndex = 0
        count = 0
    }

    var elements: [DiagnosticsSample] {
        guard count == capacity else {
            return storage.prefix(count).compactMap { $0 }
        }

        return (storage[nextWriteIndex...] + storage[..<nextWriteIndex])
            .compactMap { $0 }
    }
}
