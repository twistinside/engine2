#include <metal_stdlib>
#include "HDRPresentationParameters.metalh"
#include "HDRPresentationVertexOut.metalh"

using namespace metal;

vertex HDRPresentationVertexOut hdrPresentationVertex(
    uint vertexID [[vertex_id]]
) {
    constexpr float2 positions[] = {
        float2(-1.0f, -1.0f),
        float2( 3.0f, -1.0f),
        float2(-1.0f,  3.0f)
    };

    HDRPresentationVertexOut out;
    out.position = float4(positions[vertexID], 0.0f, 1.0f);
    return out;
}

/// Reads one scene pixel using the rasterized pixel coordinate.
static inline float3 hdrLoadFiniteSceneColor(
    HDRPresentationVertexOut in,
    texture2d<float> sceneColor
) {
    float3 color = sceneColor.read(uint2(in.position.xy)).rgb;
    return all(isfinite(color)) ? max(color, float3(0.0f)) : float3(0.0f);
}

/// Applies Reinhard without allowing a finite scene/exposure multiplication
/// that overflows to positive infinity to become the undefined `inf / inf`.
static inline float hdrReinhardNonnegative(float exposed) {
    if (!isfinite(exposed)) {
        // Valid CPU inputs can produce only positive infinity here, which is
        // the limiting white value. Treat any unexpected NaN as black rather
        // than propagating it into the drawable.
        return exposed > 0.0f ? 1.0f : 0.0f;
    }

    // The direct quotient is accurate near black. Above one, the equivalent
    // reciprocal form avoids a subnormal reciprocal being flushed to zero by
    // fast floating-point division for very large but still finite values.
    if (exposed <= 1.0f) {
        return exposed / (1.0f + exposed);
    }
    return 1.0f - 1.0f / (1.0f + exposed);
}

fragment float4 hdrToneMappedPresentationFragment(
    HDRPresentationVertexOut in [[stage_in]],
    texture2d<float> sceneColor [[texture(0)]],
    constant HDRPresentationParameters &parameters [[buffer(0)]]
) {
    float exposureInput = parameters.exposurePadding.x;
    float exposure = isfinite(exposureInput)
        ? max(exposureInput, 0.0f)
        : 0.0f;
    float3 exposed = hdrLoadFiniteSceneColor(in, sceneColor) * exposure;

    // Reinhard maps finite nonnegative scene-linear HDR into display-linear
    // 0...1. Do not apply sRGB here: the `_srgb` drawable performs that one
    // transfer encoding when this display-linear value is stored.
    float3 toneMapped = float3(
        hdrReinhardNonnegative(exposed.r),
        hdrReinhardNonnegative(exposed.g),
        hdrReinhardNonnegative(exposed.b)
    );
    return float4(toneMapped, 1.0f);
}

fragment float4 linearPresentationFragment(
    HDRPresentationVertexOut in [[stage_in]],
    texture2d<float> sceneColor [[texture(0)]]
) {
    // Diagnostics already describe display-linear 0...1 values. Preserve them
    // rather than corrupting their meaning with exposure or tone mapping.
    return float4(saturate(hdrLoadFiniteSceneColor(in, sceneColor)), 1.0f);
}
