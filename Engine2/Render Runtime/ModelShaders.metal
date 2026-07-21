#include <metal_stdlib>
#include "PBRDirectLighting.metalh"
#include "PBRSceneParameters.metalh"
using namespace metal;

/// Interleaved vertex layout supplied by the decoded model mesh buffer.
struct ModelVertex {
    float3 position;
    float3 color;
    float3 normal;
};

/// Per-draw transform and authored-material layout mirrored by `GPUInstance`.
struct ModelInstance {
    float4x4 modelViewProjectionMatrix;
    float4x4 modelViewMatrix;
    float3x3 normalMatrix;
    float4 baseColorMetallic;
    float4 perceptualRoughnessPadding;
};

/// Values interpolated from the model vertex stage into the fragment stage.
struct VertexOut {
    float4 position [[position]];
    float3 viewPosition;
    float3 viewNormal;
};

vertex VertexOut modelVertex(uint vertexID [[vertex_id]],
                             constant ModelVertex *vertices [[buffer(0)]],
                             constant ModelInstance *instance [[buffer(1)]]) {
    VertexOut out;

    float4 localPosition = float4(vertices[vertexID].position, 1.0);
    out.position = instance->modelViewProjectionMatrix * localPosition;
    out.viewPosition = (instance->modelViewMatrix * localPosition).xyz;
    out.viewNormal = instance->normalMatrix * vertices[vertexID].normal;

    return out;
}

/// Evaluates the production model inputs once for both visible shading and the
/// test-addressable M5 diagnostics below.
///
/// Keeping this helper in the ordinary model shader ensures diagnostic entry
/// points consume the same interpolated geometry, per-draw material record,
/// frame light, and shared BRDF as `modelPBRFragment`. Only the returned field
/// changes, so the validation harness does not create a parallel render path.
static inline PBRDirectLightingResult modelEvaluateDirectLighting(
    VertexOut in,
    constant ModelInstance *instance,
    constant PBRSceneParameters &parameters
) {
    float3 incidentRadiance = parameters.lightColorIntensity.rgb
        * parameters.lightColorIntensity.a;
    return pbrEvaluateDirectLighting(
        instance->baseColorMetallic.rgb,
        instance->baseColorMetallic.a,
        instance->perceptualRoughnessPadding.x,
        in.viewNormal,
        -in.viewPosition,
        parameters.directionToLightPadding.xyz,
        incidentRadiance
    );
}

fragment float4 modelPBRFragment(
    VertexOut in [[stage_in]],
    constant ModelInstance *instance [[buffer(1)]],
    constant PBRSceneParameters &parameters [[buffer(2)]]
) {
    PBRDirectLightingResult result = modelEvaluateDirectLighting(
        in,
        instance,
        parameters
    );

    return float4(result.shaded, 1.0f);
}

/// Test-addressable production-model diagnostic entry points for M5.
///
/// The app does not compile selectable pipelines for these functions. Focused
/// offscreen tests use them to inspect the exact authored inputs and BRDF
/// contributions flowing through the production model binding.
fragment float4 modelPBRBaseColorDiagnosticFragment(
    VertexOut in [[stage_in]],
    constant ModelInstance *instance [[buffer(1)]],
    constant PBRSceneParameters &parameters [[buffer(2)]]
) {
    PBRDirectLightingResult result = modelEvaluateDirectLighting(
        in,
        instance,
        parameters
    );
    return float4(result.baseColor, 1.0f);
}

fragment float4 modelPBRMetallicDiagnosticFragment(
    VertexOut in [[stage_in]],
    constant ModelInstance *instance [[buffer(1)]],
    constant PBRSceneParameters &parameters [[buffer(2)]]
) {
    PBRDirectLightingResult result = modelEvaluateDirectLighting(
        in,
        instance,
        parameters
    );
    return float4(float3(result.metallic), 1.0f);
}

fragment float4 modelPBRRoughnessDiagnosticFragment(
    VertexOut in [[stage_in]],
    constant ModelInstance *instance [[buffer(1)]],
    constant PBRSceneParameters &parameters [[buffer(2)]]
) {
    PBRDirectLightingResult result = modelEvaluateDirectLighting(
        in,
        instance,
        parameters
    );
    return float4(float3(result.perceptualRoughness), 1.0f);
}

fragment float4 modelPBRDiffuseDiagnosticFragment(
    VertexOut in [[stage_in]],
    constant ModelInstance *instance [[buffer(1)]],
    constant PBRSceneParameters &parameters [[buffer(2)]]
) {
    PBRDirectLightingResult result = modelEvaluateDirectLighting(
        in,
        instance,
        parameters
    );
    return float4(result.diffuseContribution, 1.0f);
}

fragment float4 modelPBRSpecularDiagnosticFragment(
    VertexOut in [[stage_in]],
    constant ModelInstance *instance [[buffer(1)]],
    constant PBRSceneParameters &parameters [[buffer(2)]]
) {
    PBRDirectLightingResult result = modelEvaluateDirectLighting(
        in,
        instance,
        parameters
    );
    return float4(result.specularContribution, 1.0f);
}

fragment half4 modelNormalDiagnosticFragment(VertexOut in [[stage_in]]) {
    // Perspective-correct interpolation does not preserve unit length. Restore
    // it per fragment, then remap the signed view-space direction to displayable
    // 0...1 RGB for inspection.
    float3 normal = normalize(in.viewNormal);
    return half4(half3(normal * 0.5 + 0.5), 1.0h);
}
