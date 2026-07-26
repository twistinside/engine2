import Testing

struct PBRProofOutputTests {
    @Test func everyDiagnosticHasAUniqueExternalShaderEntryPoint() {
        let functionNames = PBRProofOutput.allCases.map(
            \.fragmentFunctionName
        )

        #expect(PBRProofOutput.allCases.count == 8)
        let uniqueFunctionNames = Set(functionNames)
        #expect(uniqueFunctionNames.count == functionNames.count)
        #expect(functionNames.allSatisfy { $0.hasPrefix("pbrProof") })
    }
}
