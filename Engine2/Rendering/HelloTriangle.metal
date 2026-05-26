//
//  HelloTriangle.metal
//  Engine2
//
//  Created by Codex on 5/25/26.
//

#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    half4 color;
};

vertex VertexOut helloTriangleVertex(uint vertexID [[vertex_id]]) {
    constexpr float2 positions[] = {
        float2(0.0, 0.75),
        float2(-0.75, -0.65),
        float2(0.75, -0.65)
    };

    constexpr half4 colors[] = {
        half4(1.0h, 0.18h, 0.16h, 1.0h),
        half4(0.18h, 0.76h, 0.32h, 1.0h),
        half4(0.20h, 0.44h, 1.0h, 1.0h)
    };

    VertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.color = colors[vertexID];

    return out;
}

fragment half4 helloTriangleFragment(VertexOut in [[stage_in]]) {
    return in.color;
}
