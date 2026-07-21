import Foundation

/// Strict decoder that rejects partial or plausibly empty diagnostic streams.
struct DiagnosticsNDJSONDecoder {
    private let decoder = JSONDecoder()

    func decode(_ data: Data) throws -> [DiagnosticsStreamRecord] {
        guard data.last == 0x0A else {
            throw DiagnosticsArtifactError.truncatedStream
        }

        let lines = data.split(separator: 0x0A, omittingEmptySubsequences: false)
        var records: [DiagnosticsStreamRecord] = []
        for (index, line) in lines.dropLast().enumerated() {
            guard !line.isEmpty else {
                throw DiagnosticsArtifactError.emptyRecord(line: index + 1)
            }
            let record = try decoder.decode(DiagnosticsStreamRecord.self, from: Data(line))
            try record.validate()
            records.append(record)
        }
        return records
    }
}
