#include <metal_stdlib>
#include "GPUPlanetInstance.h"
#include "PlanetVertexOut.metalh"
#include "../PBR/ModelVertex.h"
#include "../PBR/PBRDirectLighting.metalh"
#include "../PBR/PBRSceneParameters.h"

using namespace metal;

static inline float2 planetWrappedUV(float2 uv) {
    return float2(fract(uv.x), clamp(uv.y, 0.0f, 1.0f));
}

static inline float2 planetSphericalUV(float3 directionInput) {
    float3 direction = pbrSafeNormalize(
        directionInput,
        float3(0.0f, 1.0f, 0.0f)
    );
    float longitude = atan2(direction.z, direction.x);
    float u = longitude * 0.15915494309189535f + 0.5f;
    float v = acos(clamp(direction.y, -1.0f, 1.0f)) * M_1_PI_F;
    return planetWrappedUV(float2(u, v));
}

static inline float3 planetSurfaceNormalLocal(
    float3 localDirection,
    texture2d<float> normalTexture,
    sampler planetSampler,
    constant GPUPlanetInstance &instance
) {
    float horizontalLengthSquared = dot(
        localDirection.xz,
        localDirection.xz
    );
    float3 tangent = float3(1.0f, 0.0f, 0.0f);
    if (horizontalLengthSquared > 1e-8f) {
        float inverseHorizontalLength = rsqrt(horizontalLengthSquared);
        tangent = float3(
            -localDirection.z * inverseHorizontalLength,
            0.0f,
            localDirection.x * inverseHorizontalLength
        );
    }
    float3 bitangent = pbrSafeNormalize(
        cross(localDirection, tangent),
        float3(0.0f, 0.0f, -1.0f)
    );

    float3 tangentNormal = normalTexture.sample(
        planetSampler,
        planetSphericalUV(localDirection)
    ).xyz * 2.0f - 1.0f;
    float poleWeight = smoothstep(
        0.0f,
        0.02f,
        sqrt(horizontalLengthSquared)
    );
    tangentNormal.xy *= poleWeight;
    tangentNormal = pbrSafeNormalize(
        tangentNormal,
        float3(0.0f, 0.0f, 1.0f)
    );

    float3 mappedNormal = pbrSafeNormalize(
        tangent * tangentNormal.x
            + bitangent * tangentNormal.y
            + localDirection * tangentNormal.z,
        localDirection
    );
    if (dot(mappedNormal, localDirection) < 0.0f) {
        mappedNormal = -mappedNormal;
    }

    float normalStrength = saturate(
        instance.surfaceCloudAtmosphereNormalStrength.w
    );
    return pbrSafeNormalize(
        mix(localDirection, mappedNormal, normalStrength),
        localDirection
    );
}

static inline float planetCloudOpacity(
    float4 cloudSample,
    float authoredOpacity
) {
    float coverage = saturate(max(cloudSample.r, cloudSample.a));
    float density = saturate(cloudSample.g);
    float detail = mix(0.92f, 1.08f, saturate(cloudSample.b));
    return saturate(
        coverage
            * mix(0.62f, 1.0f, density)
            * detail
            * authoredOpacity
    );
}

static inline float planetCloudShadow(
    float3 localDirection,
    float localRadius,
    texture2d<float> cloudTexture,
    sampler planetSampler,
    constant GPUPlanetInstance &instance
) {
    float cloudRadius = instance.surfaceCloudAtmosphereNormalStrength.y;
    if (cloudRadius <= localRadius) {
        return 0.0f;
    }

    float3 directionToLight = pbrSafeNormalize(
        instance.directionToLightLocalPadding.xyz,
        float3(0.0f, 0.0f, 1.0f)
    );
    float3 localPosition = localDirection * localRadius;
    float projectedPosition = dot(localPosition, directionToLight);
    float discriminant = projectedPosition * projectedPosition
        - dot(localPosition, localPosition)
        + cloudRadius * cloudRadius;
    float distanceToShell = -projectedPosition
        + sqrt(max(discriminant, 0.0f));
    float3 shadowDirection = pbrSafeNormalize(
        localPosition + directionToLight * max(distanceToShell, 0.0f),
        localDirection
    );
    float4 cloudSample = cloudTexture.sample(
        planetSampler,
        planetSphericalUV(shadowDirection)
    );
    return planetCloudOpacity(
        cloudSample,
        instance.cloudAtmosphereParameters.x
    ) * saturate(instance.cloudAtmosphereParameters.z);
}

static inline PlanetVertexOut planetShellVertex(
    uint vertexID,
    constant ModelVertex *vertices,
    constant GPUPlanetInstance &instance,
    float radius
) {
    PlanetVertexOut out;
    float3 localDirection = pbrSafeNormalize(
        vertices[vertexID].position,
        float3(0.0f, 1.0f, 0.0f)
    );
    float4 localPosition = float4(localDirection * radius, 1.0f);

    out.position = instance.modelViewProjectionMatrix * localPosition;
    out.viewPosition = (instance.modelViewMatrix * localPosition).xyz;
    out.localDirection = localDirection;
    out.localRadius = radius;
    return out;
}

vertex PlanetVertexOut terrestrialPlanetSurfaceVertex(
    uint vertexID [[vertex_id]],
    constant ModelVertex *vertices [[buffer(0)]],
    constant GPUPlanetInstance &instance [[buffer(1)]]
) {
    return planetShellVertex(
        vertexID,
        vertices,
        instance,
        instance.surfaceCloudAtmosphereNormalStrength.x
    );
}

vertex PlanetVertexOut terrestrialPlanetCloudVertex(
    uint vertexID [[vertex_id]],
    constant ModelVertex *vertices [[buffer(0)]],
    constant GPUPlanetInstance &instance [[buffer(1)]]
) {
    return planetShellVertex(
        vertexID,
        vertices,
        instance,
        instance.surfaceCloudAtmosphereNormalStrength.y
    );
}

vertex PlanetVertexOut terrestrialPlanetAtmosphereVertex(
    uint vertexID [[vertex_id]],
    constant ModelVertex *vertices [[buffer(0)]],
    constant GPUPlanetInstance &instance [[buffer(1)]]
) {
    return planetShellVertex(
        vertexID,
        vertices,
        instance,
        instance.surfaceCloudAtmosphereNormalStrength.z
    );
}

fragment float4 terrestrialPlanetSurfaceFragment(
    PlanetVertexOut in [[stage_in]],
    constant GPUPlanetInstance &instance [[buffer(1)]],
    constant PBRSceneParameters &scene [[buffer(2)]],
    texture2d<float> normalTexture [[texture(0)]],
    texture2d<float> surfaceTexture [[texture(1)]],
    texture2d<float> controlTexture [[texture(2)]],
    texture2d<float> cloudTexture [[texture(3)]],
    sampler planetSampler [[sampler(0)]]
) {
    float3 localDirection = pbrSafeNormalize(
        in.localDirection,
        float3(0.0f, 1.0f, 0.0f)
    );
    float2 uv = planetSphericalUV(localDirection);
    float4 surface = surfaceTexture.sample(planetSampler, uv);
    float4 control = controlTexture.sample(planetSampler, uv);
    float landMask = smoothstep(0.35f, 0.65f, surface.a);
    float3 baseColor = max(surface.rgb, float3(0.0f));
    float perceptualRoughness = clamp(control.a, 0.04f, 1.0f);

    float3 surfaceNormalLocal = planetSurfaceNormalLocal(
        localDirection,
        normalTexture,
        planetSampler,
        instance
    );
    float3 surfaceNormalView = pbrSafeNormalize(
        instance.normalMatrix * surfaceNormalLocal,
        float3(0.0f, 0.0f, 1.0f)
    );
    float3 directionToCameraView = pbrSafeNormalize(
        -in.viewPosition,
        float3(0.0f, 0.0f, 1.0f)
    );
    float3 directionToLightView = pbrSafeNormalize(
        instance.directionToLightViewPadding.xyz,
        float3(0.0f, 0.0f, 1.0f)
    );
    float3 incidentRadiance = float3(1.0f, 0.99f, 0.96f)
        * max(scene.lightColorIntensity.a, 0.0f);
    PBRDirectLightingResult lighting = pbrEvaluateDirectLighting(
        baseColor,
        0.0f,
        perceptualRoughness,
        surfaceNormalView,
        directionToCameraView,
        directionToLightView,
        incidentRadiance
    );

    float cloudShadow = planetCloudShadow(
        localDirection,
        in.localRadius,
        cloudTexture,
        planetSampler,
        instance
    );
    float lowAmbient = mix(0.045f, 0.075f, landMask);
    float3 color = lighting.shaded * (1.0f - cloudShadow)
        + baseColor * lowAmbient;
    return float4(max(color, float3(0.0f)), 1.0f);
}

fragment float4 terrestrialPlanetCloudFragment(
    PlanetVertexOut in [[stage_in]],
    constant GPUPlanetInstance &instance [[buffer(1)]],
    constant PBRSceneParameters &scene [[buffer(2)]],
    texture2d<float> cloudTexture [[texture(3)]],
    sampler planetSampler [[sampler(0)]]
) {
    float3 localDirection = pbrSafeNormalize(
        in.localDirection,
        float3(0.0f, 1.0f, 0.0f)
    );
    float4 cloudSample = cloudTexture.sample(
        planetSampler,
        planetSphericalUV(localDirection)
    );
    float opacity = planetCloudOpacity(
        cloudSample,
        instance.cloudAtmosphereParameters.x
    );
    float3 directionToLightLocal = pbrSafeNormalize(
        instance.directionToLightLocalPadding.xyz,
        float3(0.0f, 0.0f, 1.0f)
    );
    float3 directionToLightView = pbrSafeNormalize(
        instance.directionToLightViewPadding.xyz,
        float3(0.0f, 0.0f, 1.0f)
    );
    float3 directionToCameraView = pbrSafeNormalize(
        -in.viewPosition,
        float3(0.0f, 0.0f, 1.0f)
    );
    float3 viewNormal = pbrSafeNormalize(
        instance.normalMatrix * localDirection,
        float3(0.0f, 0.0f, 1.0f)
    );
    float direct = saturate(dot(localDirection, directionToLightLocal));
    float rim = pow(
        1.0f - saturate(dot(viewNormal, directionToCameraView)),
        2.0f
    );
    float forwardAlignment = saturate(
        dot(-directionToLightView, directionToCameraView)
    );
    float silverLining = pow(forwardAlignment, 8.0f) * rim;
    float3 incidentRadiance = float3(1.0f, 0.99f, 0.96f)
        * max(scene.lightColorIntensity.a, 0.0f);
    float lighting = 0.42f + direct * 0.58f + silverLining * 0.20f;
    float3 radiance = float3(0.10f, 0.13f, 0.18f)
        + incidentRadiance * lighting * 0.27f;
    return float4(radiance * opacity, opacity);
}

static inline float planetHenyeyGreenstein(float cosine, float asymmetry) {
    float g = clamp(asymmetry, -0.95f, 0.95f);
    float denominator = max(
        1.0f + g * g - 2.0f * g * cosine,
        1e-4f
    );
    return (1.0f - g * g) / pow(denominator, 1.5f);
}

fragment float4 terrestrialPlanetAtmosphereFragment(
    PlanetVertexOut in [[stage_in]],
    constant GPUPlanetInstance &instance [[buffer(1)]],
    constant PBRSceneParameters &scene [[buffer(2)]]
) {
    float3 localDirection = pbrSafeNormalize(
        in.localDirection,
        float3(0.0f, 1.0f, 0.0f)
    );
    float3 directionToLightLocal = pbrSafeNormalize(
        instance.directionToLightLocalPadding.xyz,
        float3(0.0f, 0.0f, 1.0f)
    );
    float3 directionToLightView = pbrSafeNormalize(
        instance.directionToLightViewPadding.xyz,
        float3(0.0f, 0.0f, 1.0f)
    );
    float3 directionToCameraView = pbrSafeNormalize(
        -in.viewPosition,
        float3(0.0f, 0.0f, 1.0f)
    );
    float3 viewNormal = pbrSafeNormalize(
        instance.normalMatrix * localDirection,
        float3(0.0f, 0.0f, 1.0f)
    );

    float limb = pow(
        1.0f - saturate(dot(viewNormal, directionToCameraView)),
        2.35f
    );
    float localLightCosine = dot(localDirection, directionToLightLocal);
    float daylight = smoothstep(-0.28f, 0.16f, localLightCosine);
    float scatteringCosine = clamp(
        dot(-directionToLightView, directionToCameraView),
        -1.0f,
        1.0f
    );
    float rayleighPhase = 0.75f
        * (1.0f + scatteringCosine * scatteringCosine);
    float miePhase = min(
        planetHenyeyGreenstein(scatteringCosine, 0.68f),
        8.0f
    );
    float intensity = max(
        instance.cloudAtmosphereParameters.y,
        0.0f
    );
    float3 rayleigh = float3(0.08f, 0.30f, 0.82f)
        * rayleighPhase * (0.08f + limb * 0.92f) * daylight;
    float3 mie = float3(0.72f, 0.82f, 1.0f)
        * miePhase * limb * daylight * 0.045f;
    float baseOpacity = saturate(
        (0.008f + limb * 0.46f)
            * (0.08f + daylight * 0.92f)
    );
    float opacity = saturate(baseOpacity * intensity);
    float3 premultipliedScattering = max(
        (rayleigh + mie) * baseOpacity * intensity,
        float3(0.0f)
    );
    return float4(premultipliedScattering, opacity);
}

fragment float4 terrestrialPlanetNormalDiagnosticFragment(
    PlanetVertexOut in [[stage_in]],
    constant GPUPlanetInstance &instance [[buffer(1)]],
    constant PBRSceneParameters &scene [[buffer(2)]],
    texture2d<float> normalTexture [[texture(0)]],
    sampler planetSampler [[sampler(0)]]
) {
    float3 localDirection = pbrSafeNormalize(
        in.localDirection,
        float3(0.0f, 1.0f, 0.0f)
    );
    float3 surfaceNormalLocal = planetSurfaceNormalLocal(
        localDirection,
        normalTexture,
        planetSampler,
        instance
    );
    float3 normalView = pbrSafeNormalize(
        instance.normalMatrix * surfaceNormalLocal,
        float3(0.0f, 0.0f, 1.0f)
    );

    // Keep the diagnostic on the same frame-light binding contract.
    float finiteBinding = isfinite(scene.lightColorIntensity.a) ? 1.0f : 0.0f;
    return float4(
        (normalView * 0.5f + 0.5f) * finiteBinding,
        1.0f
    );
}
