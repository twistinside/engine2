#ifndef ENGINE2_PBR_PROOF_PARAMETERS_H
#define ENGINE2_PBR_PROOF_PARAMETERS_H

#include <simd/simd.h>

/// Test-only raw input shared by the isolated proof renderer and shader.
///
/// This provisional record remains outside the production renderer ABI, but
/// its render integration tests and shader still compile one declaration.
typedef struct PBRProofParameters {
    simd_float4 baseColorMetallic;
    simd_float4 directionToLightRoughness;
    simd_float4 lightColorIntensity;
    simd_float4 directionToCameraPadding;
} PBRProofParameters;

#endif
