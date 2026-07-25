import Testing
@testable import Engine2

struct ModelVertexTests {
    @Test func sharedLayoutMatchesTheInterleavedModelDescriptor() {
        #expect(MemoryLayout<ModelVertex>.alignment == 16)
        #expect(MemoryLayout<ModelVertex>.size == 48)
        #expect(MemoryLayout<ModelVertex>.stride == 48)
        #expect(MemoryLayout<ModelVertex>.offset(of: \.position) == 0)
        #expect(MemoryLayout<ModelVertex>.offset(of: \.color) == 16)
        #expect(MemoryLayout<ModelVertex>.offset(of: \.normal) == 32)
    }
}
