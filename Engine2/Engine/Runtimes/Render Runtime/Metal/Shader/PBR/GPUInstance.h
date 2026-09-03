#ifndef ENGINE2_GPU_INSTANCE_H
#define ENGINE2_GPU_INSTANCE_H

#include <simd/simd.h>

/// Raw per-draw transport record shared by Swift and Metal.
///
/// Render owns this wire layout. Swift derives and validates its values before
/// writing them to a frame buffer; shaders consume the same declaration.
typedef struct GPUInstance {
    simd_float4x4 modelViewProjectionMatrix;
    simd_float4x4 modelViewMatrix;
    simd_float3x3 normalMatrix;
    simd_float4 baseColorMetallic;
    simd_float4 perceptualRoughnessPadding;
} GPUInstance;

#endif
