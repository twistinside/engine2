#include <metal_stdlib>
using namespace metal;

/// Interleaved vertex layout supplied by the decoded model mesh buffer.
struct ModelVertex {
    float3 position;
    float3 color;
    float3 normal;
};

/// Per-draw transform layout mirrored by Swift's `GPUInstance`.
struct ModelInstance {
    float4x4 modelViewProjectionMatrix;
    float4x4 modelViewMatrix;
    float3x3 normalMatrix;
};

/// Values interpolated from the model vertex stage into the fragment stage.
struct VertexOut {
    float4 position [[position]];
    half4 color;
    float3 viewPosition;
    float3 viewNormal;
};

vertex VertexOut modelVertex(uint vertexID [[vertex_id]],
                             constant ModelVertex *vertices [[buffer(0)]],
                             constant ModelInstance *instance [[buffer(1)]]) {
    VertexOut out;

    float4 localPosition = float4(vertices[vertexID].position, 1.0);
    out.position = instance->modelViewProjectionMatrix * localPosition;
    out.color = half4(half3(vertices[vertexID].color), 1.0h);
    out.viewPosition = (instance->modelViewMatrix * localPosition).xyz;
    out.viewNormal = instance->normalMatrix * vertices[vertexID].normal;

    return out;
}

fragment half4 modelFragment(VertexOut in [[stage_in]]) {
    // Preserve the existing unlit display-color path until authored materials
    // replace it in the material-boundary milestone.
    return in.color;
}

fragment half4 modelNormalDiagnosticFragment(VertexOut in [[stage_in]]) {
    // Perspective-correct interpolation does not preserve unit length. Restore
    // it per fragment, then remap the signed view-space direction to displayable
    // 0...1 RGB for inspection.
    float3 normal = normalize(in.viewNormal);
    return half4(half3(normal * 0.5 + 0.5), 1.0h);
}
