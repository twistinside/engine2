//
//  ModelShaders.metal
//  Engine2
//
//  Created by Codex on 5/26/26.
//

#include <metal_stdlib>
using namespace metal;

struct ModelVertex {
    float3 position;
    float3 color;
};

struct ModelInstance {
    // xy = clip-space translation, z = uniform scale
    float4 transform;
};

struct VertexOut {
    float4 position [[position]];
    half4 color;
};

vertex VertexOut modelVertex(uint vertexID [[vertex_id]],
                             constant ModelVertex *vertices [[buffer(0)]],
                             constant ModelInstance *instance [[buffer(1)]]) {
    VertexOut out;

    float3 position = vertices[vertexID].position * instance->transform.z;
    position.xy += instance->transform.xy;

    out.position = float4(position, 1.0);
    out.color = half4(half3(vertices[vertexID].color), 1.0h);

    return out;
}

fragment half4 modelFragment(VertexOut in [[stage_in]]) {
    return in.color;
}
