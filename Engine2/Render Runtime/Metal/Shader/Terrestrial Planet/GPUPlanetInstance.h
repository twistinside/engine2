#ifndef ENGINE2_GPU_PLANET_INSTANCE_H
#define ENGINE2_GPU_PLANET_INSTANCE_H

#include <simd/simd.h>

/// Raw per-draw terrestrial-planet record shared by Swift and Metal.
///
/// The record keeps transforms, layer geometry, appearance factors, and the
/// deterministic proof-sun directions together for one prepared planet draw.
typedef struct GPUPlanetInstance {
    simd_float4x4 modelViewProjectionMatrix;
    simd_float4x4 modelViewMatrix;
    simd_float3x3 normalMatrix;
    simd_float4 surfaceReliefSeaCloudRadii;
    simd_float4 atmosphereCloudParameters;
    simd_float4 directionToLightViewPadding;
    simd_float4 directionToLightLocalPadding;
} GPUPlanetInstance;

#endif
