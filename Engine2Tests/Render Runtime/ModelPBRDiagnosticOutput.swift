/// Test-only production-model outputs used to validate authored M5 materials.
///
/// Each case selects a fragment entry point in `ModelShaders.metal` that reads
/// the ordinary model instance and light bindings, calls the same production
/// evaluator as the visible surface, and exposes one result field. These are not
/// app-facing `RenderOutputMode` cases and create no runtime pipeline variants.
enum ModelPBRDiagnosticOutput: CaseIterable, Hashable {
    case baseColor
    case metallic
    case roughness
    case diffuse
    case specular

    /// Metal entry point whose pipeline state is created only by the harness.
    ///
    /// The functions themselves remain part of the app's bundled shader
    /// library; production code exposes no pipeline identity or output mode
    /// that can select them.
    var fragmentFunctionName: String {
        switch self {
        case .baseColor:
            "modelPBRBaseColorDiagnosticFragment"

        case .metallic:
            "modelPBRMetallicDiagnosticFragment"

        case .roughness:
            "modelPBRRoughnessDiagnosticFragment"

        case .diffuse:
            "modelPBRDiffuseDiagnosticFragment"

        case .specular:
            "modelPBRSpecularDiagnosticFragment"
        }
    }
}
