import Testing
@testable import Engine2

struct MetalOffscreenSubmissionErrorTests {
    @Test func preservesDriverDescriptionForRuntimeTranslation() {
        let error = MetalOffscreenSubmissionError.gpuExecutionFailed(
            "command buffer page fault"
        )

        #expect(error.backendDescription == "command buffer page fault")
    }
}
