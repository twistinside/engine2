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

fragment float4 modelPBRFragment(
    VertexOut in [[stage_in]],
    constant ModelInstance *instance [[buffer(1)]],
    constant PBRSceneParameters &parameters [[buffer(2)]]
) {
    float3 incidentRadiance = parameters.lightColorIntensity.rgb
        * parameters.lightColorIntensity.a;
    PBRDirectLightingResult result = pbrEvaluateDirectLighting(
        instance->baseColorMetallic.rgb,
        instance->baseColorMetallic.a,
        instance->perceptualRoughnessPadding.x,
        in.viewNormal,
        -in.viewPosition,
        parameters.directionToLightPadding.xyz,
        incidentRadiance
    );

    return float4(result.shaded, 1.0f);
}

fragment half4 modelNormalDiagnosticFragment(VertexOut in [[stage_in]]) {
    // Perspective-correct interpolation does not preserve unit length. Restore
    // it per fragment, then remap the signed view-space direction to displayable
    // 0...1 RGB for inspection.
    float3 normal = normalize(in.viewNormal);
    return half4(half3(normal * 0.5 + 0.5), 1.0h);
}
