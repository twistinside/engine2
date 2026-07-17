#include <metal_stdlib>
using namespace metal;

/// Interleaved vertex layout supplied by the decoded model mesh buffer.
struct ModelVertex {
    float3 position;
    float3 color;
};

/// Per-draw transform layout mirrored by Swift's `GPUInstance`.
struct ModelInstance {
    float4x4 modelViewProjectionMatrix;
};

/// Values interpolated from the model vertex stage into the fragment stage.
struct VertexOut {
    float4 position [[position]];
    half4 color;
};

vertex VertexOut modelVertex(uint vertexID [[vertex_id]],
                             constant ModelVertex *vertices [[buffer(0)]],
                             constant ModelInstance *instance [[buffer(1)]]) {
    VertexOut out;

    out.position = instance->modelViewProjectionMatrix * float4(vertices[vertexID].position, 1.0);
    out.color = half4(half3(vertices[vertexID].color), 1.0h);

    return out;
}

fragment half4 modelFragment(VertexOut in [[stage_in]]) {
    return in.color;
}
