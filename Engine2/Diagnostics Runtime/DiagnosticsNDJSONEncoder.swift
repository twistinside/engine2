import Foundation

/// Deterministic newline-delimited encoder suitable for standard output.
struct DiagnosticsNDJSONEncoder {
    typealias Writer = (Data) throws -> Void

    private let encoder: JSONEncoder

    init() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        self.encoder = encoder
    }

    func encode(_ record: DiagnosticsStreamRecord) throws -> Data {
        try record.validate()
        var data = try encoder.encode(record)
        data.append(0x0A)
        return data
    }

    func write(
        _ record: DiagnosticsStreamRecord,
        to writer: Writer
    ) throws {
        try writer(encode(record))
    }
}
