#include <metal_stdlib>
#include "PBRDirectLighting.metalh"
#include "PBRProofParameters.metalh"
#include "PBRProofVertexOut.metalh"

using namespace metal;

vertex PBRProofVertexOut pbrProofVertex(uint vertexID [[vertex_id]]) {
    constexpr float2 positions[] = {
        float2(-1.0f, -1.0f),
        float2( 3.0f, -1.0f),
        float2(-1.0f,  3.0f)
    };

    PBRProofVertexOut out;
    float2 position = positions[vertexID];
    out.position = float4(position, 0.0f, 1.0f);
    out.uv = position * 0.5f + 0.5f;
    return out;
}

/// Evaluates a unit front hemisphere under an orthographic proof camera.
///
/// The analytic sphere removes mesh import, transforms, and production binding
/// choices from the BRDF proof. Alpha remains zero outside the discarded sphere
/// so tests can distinguish foreground samples from the clear color.
static inline PBRDirectLightingResult pbrEvaluateProofSphere(
    PBRProofVertexOut in,
    constant PBRProofParameters &parameters
) {
    float2 spherePoint = in.uv * 2.0f - 1.0f;
    float radiusSquared = dot(spherePoint, spherePoint);
    if (radiusSquared > 1.0f) {
        discard_fragment();
    }

    float3 normal = float3(
        spherePoint,
        sqrt(max(1.0f - radiusSquared, 0.0f))
    );
    float3 incidentRadiance = parameters.lightColorIntensity.rgb
        * parameters.lightColorIntensity.a;

    return pbrEvaluateDirectLighting(
        parameters.baseColorMetallic.rgb,
        parameters.baseColorMetallic.a,
        parameters.directionToLightRoughness.a,
        normal,
        parameters.directionToCameraPadding.xyz,
        parameters.directionToLightRoughness.xyz,
        incidentRadiance
    );
}

fragment float4 pbrProofShadedFragment(
    PBRProofVertexOut in [[stage_in]],
    constant PBRProofParameters &parameters [[buffer(0)]]
) {
    PBRDirectLightingResult result = pbrEvaluateProofSphere(in, parameters);
    return float4(result.shaded, 1.0f);
}

fragment float4 pbrProofNormalFragment(
    PBRProofVertexOut in [[stage_in]],
    constant PBRProofParameters &parameters [[buffer(0)]]
) {
    PBRDirectLightingResult result = pbrEvaluateProofSphere(in, parameters);
    return float4(result.normal * 0.5f + 0.5f, 1.0f);
}

fragment float4 pbrProofBaseColorFragment(
    PBRProofVertexOut in [[stage_in]],
    constant PBRProofParameters &parameters [[buffer(0)]]
) {
    PBRDirectLightingResult result = pbrEvaluateProofSphere(in, parameters);
    return float4(result.baseColor, 1.0f);
}

fragment float4 pbrProofMetallicFragment(
    PBRProofVertexOut in [[stage_in]],
    constant PBRProofParameters &parameters [[buffer(0)]]
) {
    PBRDirectLightingResult result = pbrEvaluateProofSphere(in, parameters);
    return float4(float3(result.metallic), 1.0f);
}

fragment float4 pbrProofRoughnessFragment(
    PBRProofVertexOut in [[stage_in]],
    constant PBRProofParameters &parameters [[buffer(0)]]
) {
    PBRDirectLightingResult result = pbrEvaluateProofSphere(in, parameters);
    return float4(float3(result.perceptualRoughness), 1.0f);
}

fragment float4 pbrProofNDotLFragment(
    PBRProofVertexOut in [[stage_in]],
    constant PBRProofParameters &parameters [[buffer(0)]]
) {
    PBRDirectLightingResult result = pbrEvaluateProofSphere(in, parameters);
    return float4(float3(result.nDotL), 1.0f);
}

fragment float4 pbrProofDiffuseFragment(
    PBRProofVertexOut in [[stage_in]],
    constant PBRProofParameters &parameters [[buffer(0)]]
) {
    PBRDirectLightingResult result = pbrEvaluateProofSphere(in, parameters);
    return float4(result.diffuseContribution, 1.0f);
}

fragment float4 pbrProofSpecularFragment(
    PBRProofVertexOut in [[stage_in]],
    constant PBRProofParameters &parameters [[buffer(0)]]
) {
    PBRDirectLightingResult result = pbrEvaluateProofSphere(in, parameters);
    return float4(result.specularContribution, 1.0f);
}
