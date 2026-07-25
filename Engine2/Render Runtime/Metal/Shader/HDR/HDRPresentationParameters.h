#ifndef ENGINE2_HDR_PRESENTATION_PARAMETERS_H
#define ENGINE2_HDR_PRESENTATION_PARAMETERS_H

#include <simd/simd.h>

/// Raw manual-exposure transport record shared by Swift and Metal.
///
/// The explicit four-float lane gives the presentation boundary a stable
/// 16-byte layout without assigning accidental meaning to padding.
typedef struct HDRPresentationParameters {
    simd_float4 exposurePadding;
} HDRPresentationParameters;

#endif
