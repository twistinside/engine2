#ifndef ENGINE2_MODEL_VERTEX_H
#define ENGINE2_MODEL_VERTEX_H

#include <simd/simd.h>

/// Raw interleaved model-vertex record shared by Swift and Metal.
///
/// Swift derives the Model I/O descriptor that produces this record from the
/// declaration. The shader consumes the resulting buffer through the same
/// field layout.
typedef struct ModelVertex {
    simd_float3 position;
    simd_float3 color;
    simd_float3 normal;
} ModelVertex;

#endif
