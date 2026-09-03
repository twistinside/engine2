/// Exhaustive diagnostic outputs compiled for the isolated BRDF proof.
enum PBRProofOutput: CaseIterable, Hashable {
    case shaded
    case normal
    case baseColor
    case metallic
    case roughness
    case nDotL
    case diffuse
    case specular

    /// Metal requires shader entry points by their source-level string names.
    /// Keeping those externally required strings behind this closed enum keeps
    /// tests exhaustive and prevents arbitrary pipeline identities.
    var fragmentFunctionName: String {
        switch self {
        case .shaded:
            "pbrProofShadedFragment"
        case .normal:
            "pbrProofNormalFragment"
        case .baseColor:
            "pbrProofBaseColorFragment"
        case .metallic:
            "pbrProofMetallicFragment"
        case .roughness:
            "pbrProofRoughnessFragment"
        case .nDotL:
            "pbrProofNDotLFragment"
        case .diffuse:
            "pbrProofDiffuseFragment"
        case .specular:
            "pbrProofSpecularFragment"
        }
    }
}
