import Testing

@testable import StarSystemExplorer

nonisolated struct StarSystemSeedParserTests {
    private let parser = StarSystemSeedParser()

    @Test(arguments: [
        ("0", UInt64(0)),
        ("1", UInt64(1)),
        ("  42  ", UInt64(42)),
        ("18_446_744_073_709_551_615", UInt64.max),
        ("0xC0FFEE", UInt64(0xC0FFEE)),
        ("0XCA_FE", UInt64(0xCAFE)),
    ])
    func acceptsDocumentedSeedFormats(input: String, expected: UInt64) {
        #expect(parser.parse(input)?.rawValue == expected)
    }

    @Test(arguments: [
        "",
        "   ",
        "-1",
        "+1",
        "0x",
        "0xNOPE",
        "18446744073709551616",
    ])
    func rejectsInvalidOrOverflowingSeeds(input: String) {
        #expect(parser.parse(input) == nil)
    }
}
