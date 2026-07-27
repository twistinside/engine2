import simd
import Testing
@testable import Engine2

struct SIMDQuaternionTests {
    @Test func identityLeavesVectorsUnchanged() {
        let vector = SIMD3<Float>(1, -2, 3)

        #expect(simd_quatf.identity.act(vector) == vector)
        #expect(simd_quatf.identity.vector == SIMD4<Float>(0, 0, 0, 1))
    }
}
