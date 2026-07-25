#include <metal_stdlib>
#include "GPUInstance.h"
#include "ModelVertex.h"
#include "ModelVertexOut.metalh"
#include "PBRDirectLighting.metalh"
#include "PBRSceneParameters.h"
using namespace metal;

vertex ModelVertexOut modelVertex(
    uint vertexID [[vertex_id]],
    constant ModelVertex *vertices [[buffer(0)]],
    constant GPUInstance *instance [[buffer(1)]]
) {
    ModelVertexOut out;

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
    ModelVertexOut in,
    constant GPUInstance *instance,
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
    ModelVertexOut in [[stage_in]],
    constant GPUInstance *instance [[buffer(1)]],
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
    ModelVertexOut in [[stage_in]],
    constant GPUInstance *instance [[buffer(1)]],
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
    ModelVertexOut in [[stage_in]],
    constant GPUInstance *instance [[buffer(1)]],
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
    ModelVertexOut in [[stage_in]],
    constant GPUInstance *instance [[buffer(1)]],
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
    ModelVertexOut in [[stage_in]],
    constant GPUInstance *instance [[buffer(1)]],
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
    ModelVertexOut in [[stage_in]],
    constant GPUInstance *instance [[buffer(1)]],
    constant PBRSceneParameters &parameters [[buffer(2)]]
) {
    PBRDirectLightingResult result = modelEvaluateDirectLighting(
        in,
        instance,
        parameters
    );
    return float4(result.specularContribution, 1.0f);
}

fragment half4 modelNormalDiagnosticFragment(ModelVertexOut in [[stage_in]]) {
    // Perspective-correct interpolation does not preserve unit length. Restore
    // it per fragment, then remap the signed view-space direction to displayable
    // 0...1 RGB for inspection.
    float3 normal = normalize(in.viewNormal);
    return half4(half3(normal * 0.5 + 0.5), 1.0h);
}
