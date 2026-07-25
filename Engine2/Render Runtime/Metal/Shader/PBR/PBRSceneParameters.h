#ifndef ENGINE2_PBR_SCENE_PARAMETERS_H
#define ENGINE2_PBR_SCENE_PARAMETERS_H

#include <simd/simd.h>

/// Raw frame-light transport record shared by Swift and Metal.
///
/// The record stays independent of per-draw appearance. Material factors live
/// in `GPUInstance`, while this value carries the directional light shared by
/// the frame's authored-material draws.
typedef struct PBRSceneParameters {
    simd_float4 directionToLightPadding;
    simd_float4 lightColorIntensity;
} PBRSceneParameters;

#endif
