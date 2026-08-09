cbuffer CB_PS_COMMON : register(b0)
{
  float4 COMMON_LBUF_PARAMS : packoffset(c0);
  float4 COMMON_VIEW_POSITION : packoffset(c1);
  float4 COMMON_VIEWPROJ_MATRIX[4] : packoffset(c2);
  float4 COMMON_VIEW_POSITION_COLORCAM : packoffset(c6);
  float4 COMMON_VIEWPROJ_MATRIX_COLORCAM[4] : packoffset(c7);
  float4 COMMON_VIEWPROJ_REFLECTION[4] : packoffset(c11);
  float4 COMMON_OBLIQUE_MATR[4] : packoffset(c15);
  float4 VS_REG_COMMON_FOG_PARAMS[2] : packoffset(c19);
  float4 REG_COMMON_CLIPPING_PLANE : packoffset(c21);
  float4 COMMON_VP_PARAMS[2] : packoffset(c22);
  float4 PS_REG_COMMON_HDR_PARAMS : packoffset(c24);
  float4 PS_REG_COMMON_FOG_SUN_DIR : packoffset(c25);
  float4 PS_REG_COMMON_FOG_RAYLEIGH_FACTOR : packoffset(c26);
  float4 PS_REG_COMMON_FOG_COLOR : packoffset(c27);
  float4 PS_REG_COMMON_FOG_PLANE_MIRROR : packoffset(c28);
  float4 PS_REG_COMMON_FOG_ATMOSPHERE_0[6] : packoffset(c29);
  float4 PS_REG_COMMON_FOG_ATMOSPHERE_EXTRA : packoffset(c35);
  float4 PS_REG_COMMON_ELAPSED_TIME : packoffset(c36);
  float4 PS_REG_COMMON_AMBIENT : packoffset(c37);
  float4 PS_REG_COMMON_DEBUG_SHOW_LIGHTING : packoffset(c38);
  float4 VS_REG_COMMON_FOG_COLOR : packoffset(c39);
  float4 VS_REG_COMMON_FOG_SUN_DIR : packoffset(c40);
  float4 VS_REG_COMMON_FOG_RAYLEIGH_FACTOR : packoffset(c41);
  float4 VS_REG_COMMON_FOG_VOLUME_COUNT : packoffset(c42);
  float4 VS_REG_COMMON_FOG_VOL_START[32] : packoffset(c43);
}

cbuffer CB_DYNAMIC_PASS_SSAO : register(b7)
{
  float4 PS_REG_SSAO_SCREEN : packoffset(c0);
  float4 PS_REG_SSAO_PARAMS : packoffset(c1);
  float4 PS_REG_SSAO_MV_1 : packoffset(c2);
  float4 PS_REG_SSAO_MV_2 : packoffset(c3);
  float4 PS_REG_SSAO_MV_3 : packoffset(c4);
  float4 SSAO_FRUSTUM_SCALE : packoffset(c5);
  float4 SSAO_TEX_COORD_SCALE : packoffset(c6);
  float4 PS_REG_SSAO_FRUSTUM_SCALE : packoffset(c7);
}

SamplerState PS_SAMPLERS_0__s : register(s0);
SamplerState PS_SAMPLERS_3__s : register(s3);
Texture2D<float4> PS_TEXTURES_2D_0_ : register(t0); //depth
Texture2D<float4> PS_TEXTURES_2D_2_ : register(t2); //per-pixel rotation/dither (2x 2D vectors, [-1,1], used to jitter the AO kernel)
Texture2D<float4> PS_TEXTURES_2D_3_ : register(t3); //normal

// 3Dmigoto declarations
#define cmp -
#include "./Includes/Common.hlsl"
#include "./Includes/Math.hlsl"

// #define USE_GTAO 1

#if USE_GTAO == 1
  #include "./Includes/XeGTAO.hlsl"
#else
  // Fixed 8-tap kernel (bit-exact to the original shader). Each tap is rotated per-pixel by the dither
  // vectors (ditherA/ditherB) via a dot product, i.e. tapDir = (dot(kernelDir, ditherA), dot(kernelDir, ditherB)).
  static const float2 AO_KERNEL_DIR[8] =
  {
    float2(0.0666666701, -0.0666666701),
    float2(-0.0599999987, -0.0599999987),
    float2(0.0533333346, 0.0533333346),
    float2(-0.0466666669, 0.0466666669),
    float2(-0.0424264073, 0),
    float2(0.0353553407, 0),
    float2(0, -0.0318198055),
    float2(0, 0.0282842703),
  };
  static const float AO_KERNEL_DEPTH_BIAS[8] =
  {
    0.0333333351, 0.0299999993, 0.0266666673, 0.0233333334,
    0.0424264073, 0.0353553407, 0.0318198055, 0.0282842703,
  };

  // One horizon-based occlusion tap: offsets the view-space position along a dithered kernel direction,
  // reflects it around the normal-bent view direction, reprojects it to screen space and diffs the depths.
  // Also recovers the *actual* view-space occluder position (GTAO-style) from the real sampled depth
  // (instead of trusting the assumed tap depth) to derive a horizon cosine and sample distance, used below
  // to weight taps the way GTAO's cosine-weighted horizon integration does, without needing a full
  // multi-step horizon march (this depth/view-space isn't reliable enough for that here).
  float SampleHorizonTapDelta(float2 kernelDir, float depthBias, float2 ditherA, float2 ditherB, float3 bendDir, float3 viewNormal, float3 centerViewPos, float aoRange, float2 frustumScale, out float horizonCos, out float sampleDist)
  {
    float2 tapDir = float2(dot(kernelDir, ditherA), dot(kernelDir, ditherB));
    float3 tapOffset = float3(tapDir, depthBias);
    tapOffset = reflect(tapOffset, bendDir);
    float3 samplePos = tapOffset * aoRange + centerViewPos;
    float2 sampleScreenDir = samplePos.xy / samplePos.z;
    float2 sampleUV = sampleScreenDir * frustumScale + 0.5;

    float sampleDepth = PS_TEXTURES_2D_0_.Sample(PS_SAMPLERS_3__s, sampleUV).x;
    float sampleLinearDepth = 0.100000016 / (1.33333344e-007 + sampleDepth);

    // Real occluder view-space position, reprojected using its own depth rather than the assumed tap depth.
    float3 actualSamplePos = float3(sampleScreenDir * sampleLinearDepth, sampleLinearDepth);
    float3 toSample = actualSamplePos - centerViewPos;
    sampleDist = length(toSample) * 0.78;
    horizonCos = dot(toSample, viewNormal) / max(sampleDist, 1e-5); // cosine between occluder direction and surface normal

    return sampleLinearDepth - samplePos.z; // positive => occluder closer to camera than the sample point
  }

  // Converts a raw depth delta into a smoothed occlusion factor and its blend weight (matches the original curve),
  // further shaped by a GTAO-style cosine-weighted horizon term (grazing/back-facing occluders contribute less,
  // instead of every depth delta occluding equally) and a smooth radius falloff (fades taps out near the AO
  // range edge instead of a hard cutoff, reducing banding).
  float ShapeOcclusionTap(float delta, float normFactor1, float normFactor2, float horizonCos, float sampleDist, float falloffMul, float falloffAdd, out float weight)
  {
    float scaledDelta = delta * normFactor1;
    float curved = 1.0 - 0.5 /* 0.478 */ * (saturate(-scaledDelta) + min(1.0, abs(scaledDelta)));
    float distFalloff = saturate(sampleDist * falloffMul + falloffAdd);
    weight = max(0.5, curved) * distFalloff;
    float edge = saturate(delta * normFactor2) - 1.0;
    float occlusion = min(1.0, curved + curved) * edge + 1.0;
    return lerp(1.0, occlusion, saturate(horizonCos));
  }

  // One horizon-based occlusion tap: offsets the view-space position along a dithered kernel direction,
  // reflects it around the normal-bent view direction, reprojects it to screen space and diffs the depths.
  float SampleHorizonTapDeltaSimpler(float2 kernelDir, float depthBias, float2 ditherA, float2 ditherB, float3 bendDir, float3 centerViewPos, float aoRange, float2 frustumScale)
  {
    float2 tapDir = float2(dot(kernelDir, ditherA), dot(kernelDir, ditherB));
    float3 tapOffset = float3(tapDir, depthBias);
    tapOffset = reflect(tapOffset, bendDir);
    float3 samplePos = tapOffset * aoRange + centerViewPos;
    float2 sampleUV = (samplePos.xy / samplePos.z) * frustumScale + 0.5;

    float sampleDepth = PS_TEXTURES_2D_0_.Sample(PS_SAMPLERS_3__s, sampleUV).x;
    float sampleLinearDepth = 0.100000016 / (1.33333344e-007 + sampleDepth);
    return sampleLinearDepth - samplePos.z; // positive => occluder closer to camera than the sample point
  }

  // Converts a raw depth delta into a smoothed occlusion factor and its blend weight (matches the original curve).
  float ShapeOcclusionTapSimpler(float delta, float normFactor1, float normFactor2, out float weight)
  {
    float scaledDelta = delta * normFactor1;
    float curved = 1.0 - /* 0.5 */ 0.478 * (saturate(-scaledDelta) + min(1.0, abs(scaledDelta)));
    weight = max(0.5, curved);
    float edge = saturate(delta * normFactor2) - 1.0;
    return min(1.0, curved + curved) * edge + 1.0;
  }

#endif

void main(
  float4 v0 : SV_Position0,
  float4 v1 : TEXCOORD0,
  float4 v2 : TEXCOORD2, //unused
  float3 v3 : TEXCOORD1,
  out float2 o0 : SV_Target0)
{
#if USE_GTAO == 1
  // world space
  float3 normal = PS_TEXTURES_2D_3_.Sample(PS_SAMPLERS_3__s, v1.xy).xyz * 2.0 - 1.0;
  normal = normalize(normal);

  float3 viewspaceNormal;
  viewspaceNormal = float3(
      dot(normal, PS_REG_SSAO_MV_1.xyz), // 1: left to 0: right
      dot(normal, PS_REG_SSAO_MV_2.xyz), // 1: bottom to 0: top
      dot(normal, PS_REG_SSAO_MV_3.xyz)  // 1: grazing to 0: facing/perpendicular
  );
  viewspaceNormal.y *= -1; //confirmed inverted

  viewspaceNormal = normalize(viewspaceNormal);
  // o0.xy = viewspaceNormal.xy * 0.5 + 0.5; return;

  // float2 depthTexSize;
  // PS_TEXTURES_2D_0_.GetDimensions(depthTexSize.x, depthTexSize.y);

  float2 swapchainTexSize = LumaSettings.SwapchainSize;
  float2 swapchainTexSizeHalf = LumaSettings.SwapchainSize * 0.5;

  uint2 pixCoord = uint2(v1.xy * swapchainTexSizeHalf);

  GTAOConstants c = (GTAOConstants) 0;
  c.RenderPixelSize = 1.0 / swapchainTexSizeHalf;
  c.ViewportPixelSize = 1.0 / swapchainTexSizeHalf;
  c.ViewportSize = swapchainTexSizeHalf;

  // #define VIEWPORT_PIXEL_SIZE g_f4RTSize.zw // (width, height, 1/width, 1/height)
  // #define NDC_TO_VIEW_MUL float2(g_fTanHalfH * 2.0, g_fTanHalfV * -2.0)
  // #define NDC_TO_VIEW_ADD float2(-g_fTanHalfH, g_fTanHalfV)
  // #define NDC_TO_VIEW_MUL_X_PIXEL_SIZE (NDC_TO_VIEW_MUL * VIEWPORT_PIXEL_SIZE)
  c.NDCToViewMul = float2(
     2.0 * PS_REG_SSAO_FRUSTUM_SCALE.z / swapchainTexSizeHalf.x,
    -2.0 * PS_REG_SSAO_FRUSTUM_SCALE.w / swapchainTexSizeHalf.y
  );
  c.NDCToViewAdd = float2(-PS_REG_SSAO_FRUSTUM_SCALE.z, PS_REG_SSAO_FRUSTUM_SCALE.w);
  c.NDCToViewMul_x_PixelSize = c.NDCToViewMul; // because mul already per pixel

  c.EffectRadius = EFFECT_RADIUS;
  c.RadiusMultiplier = RADIUS_MULTIPLIER;
  c.EffectFalloffRange = EFFECT_FALLOFF_RANGE;
  c.SampleDistributionPower = SAMPLE_DISTRIBUTION_POWER;
  c.ThinOccluderCompensation = THIN_OCCLUDER_COMPENSATION;
  c.FinalValuePower = FINAL_VALUE_POWER;
  c.DepthMIPSamplingOffset = DEPTH_MIP_SAMPLING_OFFSET;
  c.DenoiseBlurBeta = DENOISE_BLUR_BETA;
  c.OcclusionTermScale = 1.0;

  float2 localNoise = DVS1/* GTAO_TemporalNoise(pixCoord, LumaSettings.FrameIndex) */;

  o0.xy = XeGTAO_MainPass(pixCoord, localNoise, viewspaceNormal, PS_TEXTURES_2D_0_, PS_SAMPLERS_3__s, c);
  return;
#else
  const float3 normal = normalize(PS_TEXTURES_2D_3_.Sample(PS_SAMPLERS_3__s, v1.xy).xyz * 2.0 - 1.0);
 
  // Transform into the space used for the AO kernel, then bend it towards the view direction; this is
  // used below to bias the sample kernel towards the surface hemisphere without a full tangent basis.
  const float3 viewNormal = float3(dot(normal, PS_REG_SSAO_MV_1.xyz), dot(normal, PS_REG_SSAO_MV_2.xyz), dot(normal, PS_REG_SSAO_MV_3.xyz));
  const float3 bendDir = normalize(float3(0, 0, -1) + viewNormal);
  // o0.xy = viewNormal.y * 0.5 + 0.5; return; //debug viewNormal

  const float4 dither = PS_TEXTURES_2D_2_.Sample(PS_SAMPLERS_0__s, v1.zw) * 2.0 - 1.0;
  const float2 ditherA = dither.xy;
  const float2 ditherB = dither.zw;

  const float centerDepth = PS_TEXTURES_2D_0_.Sample(PS_SAMPLERS_3__s, v1.xy).x;
  const float centerLinearDepth = 0.100000016 / (1.33333344e-007 + centerDepth);

  const float aoRange = saturate(0.5 * centerLinearDepth) * (PS_REG_SSAO_PARAMS.x * (centerLinearDepth * 0.100000001 + 1.39999998));
  const float3 centerViewPos = v3.xyz * centerLinearDepth / v3.z;

  const float normFactor1 = PS_REG_SSAO_PARAMS.z / aoRange;
  const float normFactor2 = 64.0 / aoRange;

  // GTAO-style smooth radius falloff (fraction of aoRange over which taps fade out near the AO range edge).
  const float AO_FALLOFF_RANGE = 0.615;
  const float falloffFrom = aoRange * (1.0 - AO_FALLOFF_RANGE);
  const float falloffRange = AO_FALLOFF_RANGE * aoRange;
  const float falloffMul = -1.0 / falloffRange;
  const float falloffAdd = falloffFrom / falloffRange + 1.0;

  #define AO_SAMPLE_COUNT_A 32
  #define AO_RING_SCALE_A 1.41
  float numerator = 0.0;
  float denominator = 0.0;
  [unroll]
//   for (int i = 0; i < AO_SAMPLE_COUNT_A; i++)
//   {
//     int slot = i % 8;
//     int ring = i / 8;
//     float ringScale = pow(AO_RING_SCALE_A, ring);
// 
//     float horizonCos, sampleDist;
//     float delta = SampleHorizonTapDelta(AO_KERNEL_DIR[slot] * ringScale, AO_KERNEL_DEPTH_BIAS[slot] * ringScale, ditherA, ditherB, bendDir, viewNormal, centerViewPos, aoRange, PS_REG_SSAO_FRUSTUM_SCALE.zw, horizonCos, sampleDist);
// 
//     float weight;
//     float occlusion = ShapeOcclusionTap(delta, normFactor1, normFactor2, horizonCos, sampleDist, falloffMul, falloffAdd, weight);
// 
//     numerator += occlusion * weight;
//     denominator += weight;
//   }
  for (int i = 0; i < AO_SAMPLE_COUNT_A; i++)
  {
    int slot = i % 8;
    int ring = i / 8;
    float ringScale = pow(AO_RING_SCALE_A, (float) ring);

    float delta = SampleHorizonTapDeltaSimpler(AO_KERNEL_DIR[slot] * ringScale, AO_KERNEL_DEPTH_BIAS[slot] * ringScale, ditherA, ditherB, bendDir, centerViewPos, aoRange, PS_REG_SSAO_FRUSTUM_SCALE.zw);

    float weight;
    float occlusion = ShapeOcclusionTapSimpler(delta, normFactor1, normFactor2, weight);

    numerator += occlusion * weight;
    denominator += weight;
  }
  float ao0 = min(1.0, numerator / denominator);

  #define AO_SAMPLE_COUNT_B 16
  #define AO_RING_SCALE_B 0.546
  numerator = 0.0;
  denominator = 0.0;
  [unroll]
  for (int i = 0; i < AO_SAMPLE_COUNT_B; i++)
  {
    int slot = i % 8;
    int ring = i / 8;
    float ringScale = pow(AO_RING_SCALE_B, ring);

    float horizonCos, sampleDist;
    float delta = SampleHorizonTapDelta(AO_KERNEL_DIR[slot] * ringScale, AO_KERNEL_DEPTH_BIAS[slot] * ringScale, ditherA, ditherB, bendDir, viewNormal, centerViewPos, aoRange, PS_REG_SSAO_FRUSTUM_SCALE.zw, horizonCos, sampleDist);

    float weight;
    float occlusion = ShapeOcclusionTap(delta, normFactor1, normFactor2, horizonCos, sampleDist, falloffMul, falloffAdd, weight);

    numerator += occlusion * weight;
    denominator += weight;
  }
  float ao1 = min(1.0, numerator / denominator);

  o0.x = min(ao0, ao1);
  // o0.x = lerp(ao0, ao1, 0.5);

  /////////////////////////////

    // Depth curvature edge-stopping term, used by the blur pass to avoid bleeding AO across depth discontinuities.
    float depthA0 = PS_TEXTURES_2D_0_.SampleLevel(PS_SAMPLERS_3__s, v1.xy - COMMON_VP_PARAMS[0].xy, 0).x;
    float depthA1 = PS_TEXTURES_2D_0_.SampleLevel(PS_SAMPLERS_3__s, v1.xy + COMMON_VP_PARAMS[0].xy, 0).x;
    float depthB0 = PS_TEXTURES_2D_0_.SampleLevel(PS_SAMPLERS_3__s, v1.xy - COMMON_VP_PARAMS[0].xy * float2(1, -1), 0).x;
    float depthB1 = PS_TEXTURES_2D_0_.SampleLevel(PS_SAMPLERS_3__s, v1.xy + COMMON_VP_PARAMS[0].xy * float2(1, -1), 0).x;
  
    float centerRemap = 0.100000016 / centerLinearDepth - 1.33333344e-007;
    float curvatureA = (depthA0 + depthA1) - 2.0 * centerRemap;
    float curvatureB = (depthB0 + depthB1) - 2.0 * centerRemap;
  
    float curvature = max(abs(curvatureA), abs(curvatureB)) * centerLinearDepth;
    o0.y = saturate(1.0 - curvature * 1024.0);

  // o0.y = 0; //NOT USED!!!
  return;

#endif
}


// cbuffer CB_PS_COMMON : register(b0)
// {
//   float4 COMMON_LBUF_PARAMS : packoffset(c0);
//   float4 COMMON_VIEW_POSITION : packoffset(c1);
//   float4 COMMON_VIEWPROJ_MATRIX[4] : packoffset(c2);
//   float4 COMMON_VIEW_POSITION_COLORCAM : packoffset(c6);
//   float4 COMMON_VIEWPROJ_MATRIX_COLORCAM[4] : packoffset(c7);
//   float4 COMMON_VIEWPROJ_REFLECTION[4] : packoffset(c11);
//   float4 COMMON_OBLIQUE_MATR[4] : packoffset(c15);
//   float4 VS_REG_COMMON_FOG_PARAMS[2] : packoffset(c19);
//   float4 REG_COMMON_CLIPPING_PLANE : packoffset(c21);
//   float4 COMMON_VP_PARAMS[2] : packoffset(c22);
//   float4 PS_REG_COMMON_HDR_PARAMS : packoffset(c24);
//   float4 PS_REG_COMMON_FOG_SUN_DIR : packoffset(c25);
//   float4 PS_REG_COMMON_FOG_RAYLEIGH_FACTOR : packoffset(c26);
//   float4 PS_REG_COMMON_FOG_COLOR : packoffset(c27);
//   float4 PS_REG_COMMON_FOG_PLANE_MIRROR : packoffset(c28);
//   float4 PS_REG_COMMON_FOG_ATMOSPHERE_0[6] : packoffset(c29);
//   float4 PS_REG_COMMON_FOG_ATMOSPHERE_EXTRA : packoffset(c35);
//   float4 PS_REG_COMMON_ELAPSED_TIME : packoffset(c36);
//   float4 PS_REG_COMMON_AMBIENT : packoffset(c37);
//   float4 PS_REG_COMMON_DEBUG_SHOW_LIGHTING : packoffset(c38);
//   float4 VS_REG_COMMON_FOG_COLOR : packoffset(c39);
//   float4 VS_REG_COMMON_FOG_SUN_DIR : packoffset(c40);
//   float4 VS_REG_COMMON_FOG_RAYLEIGH_FACTOR : packoffset(c41);
//   float4 VS_REG_COMMON_FOG_VOLUME_COUNT : packoffset(c42);
//   float4 VS_REG_COMMON_FOG_VOL_START[32] : packoffset(c43);
// }
// 
// cbuffer CB_DYNAMIC_PASS_SSAO : register(b7)
// {
//   float4 PS_REG_SSAO_SCREEN : packoffset(c0);
//   float4 PS_REG_SSAO_PARAMS : packoffset(c1);
//   float4 PS_REG_SSAO_MV_1 : packoffset(c2);
//   float4 PS_REG_SSAO_MV_2 : packoffset(c3);
//   float4 PS_REG_SSAO_MV_3 : packoffset(c4);
//   float4 SSAO_FRUSTUM_SCALE : packoffset(c5);
//   float4 SSAO_TEX_COORD_SCALE : packoffset(c6);
//   float4 PS_REG_SSAO_FRUSTUM_SCALE : packoffset(c7);
// }
// 
// SamplerState PS_SAMPLERS_0__s : register(s0);
// SamplerState PS_SAMPLERS_3__s : register(s3);
// Texture2D<float4> PS_TEXTURES_2D_0_ : register(t0); //depth
// Texture2D<float4> PS_TEXTURES_2D_2_ : register(t2); //per-pixel rotation/dither (2x 2D vectors, [-1,1], used to jitter the AO kernel)
// Texture2D<float4> PS_TEXTURES_2D_3_ : register(t3); //normal
// 
// // 3Dmigoto declarations
// #define cmp -
// #include "./Includes/Common.hlsl"
// #include "./Includes/Math.hlsl"
// 
// // #define USE_GTAO 1
// 
// #if USE_GTAO == 1
//   #include "./Includes/XeGTAO.hlsl"
// #else
//   // Number of horizon-tap samples; 8 = original quality/appearance. Extra samples are added as additional
//   // spiral rings (shrunk by AO_RING_SCALE per ring) for higher quality, at a proportional performance cost.
//   #define AO_SAMPLE_COUNT 42 //8
//   #define AO_RING_SCALE 1.15 //0.75
// 
//   // Fixed 8-tap kernel (bit-exact to the original shader). Each tap is rotated per-pixel by the dither
//   // vectors (ditherA/ditherB) via a dot product, i.e. tapDir = (dot(kernelDir, ditherA), dot(kernelDir, ditherB)).
//   static const float2 AO_KERNEL_DIR[8] =
//   {
//     float2(0.0666666701, -0.0666666701),
//     float2(-0.0599999987, -0.0599999987),
//     float2(0.0533333346, 0.0533333346),
//     float2(-0.0466666669, 0.0466666669),
//     float2(-0.0424264073, 0),
//     float2(0.0353553407, 0),
//     float2(0, -0.0318198055),
//     float2(0, 0.0282842703),
//   };
//   static const float AO_KERNEL_DEPTH_BIAS[8] =
//   {
//     0.0333333351, 0.0299999993, 0.0266666673, 0.0233333334,
//     0.0424264073, 0.0353553407, 0.0318198055, 0.0282842703,
//   };
// 
//   // One horizon-based occlusion tap: offsets the view-space position along a dithered kernel direction,
//   // reflects it around the normal-bent view direction, reprojects it to screen space and diffs the depths.
//   float SampleHorizonTapDelta(float2 kernelDir, float depthBias, float2 ditherA, float2 ditherB, float3 bendDir, float3 centerViewPos, float aoRange, float2 frustumScale)
//   {
//     float2 tapDir = float2(dot(kernelDir, ditherA), dot(kernelDir, ditherB));
//     float3 tapOffset = float3(tapDir, depthBias);
//     tapOffset = reflect(tapOffset, bendDir);
//     float3 samplePos = tapOffset * aoRange + centerViewPos;
//     float2 sampleUV = (samplePos.xy / samplePos.z) * frustumScale + 0.5;
// 
//     float sampleDepth = PS_TEXTURES_2D_0_.Sample(PS_SAMPLERS_3__s, sampleUV).x;
//     float sampleLinearDepth = 0.100000016 / (1.33333344e-007 + sampleDepth);
//     return sampleLinearDepth - samplePos.z; // positive => occluder closer to camera than the sample point
//   }
// 
//   // Converts a raw depth delta into a smoothed occlusion factor and its blend weight (matches the original curve).
//   float ShapeOcclusionTap(float delta, float normFactor1, float normFactor2, out float weight)
//   {
//     float scaledDelta = delta * normFactor1;
//     float curved = 1.0 - /* 0.5 */ 0.478 * (saturate(-scaledDelta) + min(1.0, abs(scaledDelta)));
//     weight = max(0.5, curved);
//     float edge = saturate(delta * normFactor2) - 1.0;
//     return min(1.0, curved + curved) * edge + 1.0;
//   }
// #endif
// 
// void main(
//   float4 v0 : SV_Position0,
//   float4 v1 : TEXCOORD0,
//   float4 v2 : TEXCOORD2, //unused
//   float3 v3 : TEXCOORD1,
//   out float2 o0 : SV_Target0)
// {
// #if USE_GTAO == 1
//   // world space
//   float3 normal = PS_TEXTURES_2D_3_.Sample(PS_SAMPLERS_3__s, v1.xy).xyz * 2.0 - 1.0;
//   normal = normalize(normal);
// 
//   float3 viewspaceNormal;
//   viewspaceNormal = float3(
//       dot(normal, PS_REG_SSAO_MV_1.xyz), // 1: left to 0: right
//       dot(normal, PS_REG_SSAO_MV_2.xyz), // 1: bottom to 0: top
//       dot(normal, PS_REG_SSAO_MV_3.xyz)  // 1: grazing to 0: facing/perpendicular
//   );
//   viewspaceNormal.y *= -1; //confirmed inverted
// 
//   viewspaceNormal = normalize(viewspaceNormal);
//   // o0.xy = viewspaceNormal.xy * 0.5 + 0.5; return;
// 
//   // float2 depthTexSize;
//   // PS_TEXTURES_2D_0_.GetDimensions(depthTexSize.x, depthTexSize.y);
// 
//   float2 swapchainTexSize = LumaSettings.SwapchainSize;
//   float2 swapchainTexSizeHalf = LumaSettings.SwapchainSize * 0.5;
// 
//   uint2 pixCoord = uint2(v1.xy * swapchainTexSizeHalf);
// 
//   GTAOConstants c = (GTAOConstants) 0;
//   c.RenderPixelSize = 1.0 / swapchainTexSizeHalf;
//   c.ViewportPixelSize = 1.0 / swapchainTexSizeHalf;
//   c.ViewportSize = swapchainTexSizeHalf;
// 
//   // #define VIEWPORT_PIXEL_SIZE g_f4RTSize.zw // (width, height, 1/width, 1/height)
//   // #define NDC_TO_VIEW_MUL float2(g_fTanHalfH * 2.0, g_fTanHalfV * -2.0)
//   // #define NDC_TO_VIEW_ADD float2(-g_fTanHalfH, g_fTanHalfV)
//   // #define NDC_TO_VIEW_MUL_X_PIXEL_SIZE (NDC_TO_VIEW_MUL * VIEWPORT_PIXEL_SIZE)
//   c.NDCToViewMul = float2(
//      2.0 * PS_REG_SSAO_FRUSTUM_SCALE.z / swapchainTexSizeHalf.x,
//     -2.0 * PS_REG_SSAO_FRUSTUM_SCALE.w / swapchainTexSizeHalf.y
//   );
//   c.NDCToViewAdd = float2(-PS_REG_SSAO_FRUSTUM_SCALE.z, PS_REG_SSAO_FRUSTUM_SCALE.w);
//   c.NDCToViewMul_x_PixelSize = c.NDCToViewMul; // because mul already per pixel
// 
//   c.EffectRadius = EFFECT_RADIUS;
//   c.RadiusMultiplier = RADIUS_MULTIPLIER;
//   c.EffectFalloffRange = EFFECT_FALLOFF_RANGE;
//   c.SampleDistributionPower = SAMPLE_DISTRIBUTION_POWER;
//   c.ThinOccluderCompensation = THIN_OCCLUDER_COMPENSATION;
//   c.FinalValuePower = FINAL_VALUE_POWER;
//   c.DepthMIPSamplingOffset = DEPTH_MIP_SAMPLING_OFFSET;
//   c.DenoiseBlurBeta = DENOISE_BLUR_BETA;
//   c.OcclusionTermScale = 1.0;
// 
//   float2 localNoise = DVS1/* GTAO_TemporalNoise(pixCoord, LumaSettings.FrameIndex) */;
// 
//   o0.xy = XeGTAO_MainPass(pixCoord, localNoise, viewspaceNormal, PS_TEXTURES_2D_0_, PS_SAMPLERS_3__s, c);
//   return;
// #else
//   float3 normal = PS_TEXTURES_2D_3_.Sample(PS_SAMPLERS_3__s, v1.xy).xyz * 2.0 - 1.0;
//   normal = normalize(normal);
// 
//   // Transform into the space used for the AO kernel, then bend it towards the view direction; this is
//   // used below to bias the sample kernel towards the surface hemisphere without a full tangent basis.
//   float3 viewNormal = float3(dot(normal, PS_REG_SSAO_MV_1.xyz), dot(normal, PS_REG_SSAO_MV_2.xyz), dot(normal, PS_REG_SSAO_MV_3.xyz));
//   float3 bendDir = normalize(float3(0, 0, -1) + viewNormal);
//   // o0.xy = viewNormal.y * 0.5 + 0.5; return; //debug viewNormal
// 
//   float4 dither = PS_TEXTURES_2D_2_.Sample(PS_SAMPLERS_0__s, v1.zw) * 2.0 - 1.0;
//   float2 ditherA = dither.xy;
//   float2 ditherB = dither.zw;
// 
//   float centerDepth = PS_TEXTURES_2D_0_.Sample(PS_SAMPLERS_3__s, v1.xy).x;
//   float centerLinearDepth = 0.100000016 / (1.33333344e-007 + centerDepth);
// 
//   float aoRange = saturate(0.5 * centerLinearDepth) * (PS_REG_SSAO_PARAMS.x * (centerLinearDepth * 0.100000001 + 1.39999998));
//   float3 centerViewPos = v3.xyz * centerLinearDepth / v3.z;
// 
//   float normFactor1 = PS_REG_SSAO_PARAMS.z / aoRange;
//   float normFactor2 = 64.0 / aoRange;
// 
//   float numerator = 0.0;
//   float denominator = 0.0;
// 
//   [unroll]
//   for (int i = 0; i < AO_SAMPLE_COUNT; i++)
//   {
//     int slot = i % 8;
//     int ring = i / 8;
//     float ringScale = pow(AO_RING_SCALE, (float) ring);
// 
//     float delta = SampleHorizonTapDelta(AO_KERNEL_DIR[slot] * ringScale, AO_KERNEL_DEPTH_BIAS[slot] * ringScale, ditherA, ditherB, bendDir, centerViewPos, aoRange, PS_REG_SSAO_FRUSTUM_SCALE.zw);
// 
//     float weight;
//     float occlusion = ShapeOcclusionTap(delta, normFactor1, normFactor2, weight);
// 
//     numerator += occlusion * weight;
//     denominator += weight;
//   }
// 
//   o0.x = min(1.0, numerator / denominator);
// 
//   /////////////////////////////
// 
//     // Depth curvature edge-stopping term, used by the blur pass to avoid bleeding AO across depth discontinuities.
//     float depthA0 = PS_TEXTURES_2D_0_.SampleLevel(PS_SAMPLERS_3__s, v1.xy - COMMON_VP_PARAMS[0].xy, 0).x;
//     float depthA1 = PS_TEXTURES_2D_0_.SampleLevel(PS_SAMPLERS_3__s, v1.xy + COMMON_VP_PARAMS[0].xy, 0).x;
//     float depthB0 = PS_TEXTURES_2D_0_.SampleLevel(PS_SAMPLERS_3__s, v1.xy - COMMON_VP_PARAMS[0].xy * float2(1, -1), 0).x;
//     float depthB1 = PS_TEXTURES_2D_0_.SampleLevel(PS_SAMPLERS_3__s, v1.xy + COMMON_VP_PARAMS[0].xy * float2(1, -1), 0).x;
//   
//     float centerRemap = 0.100000016 / centerLinearDepth - 1.33333344e-007;
//     float curvatureA = (depthA0 + depthA1) - 2.0 * centerRemap;
//     float curvatureB = (depthB0 + depthB1) - 2.0 * centerRemap;
//   
//     float curvature = max(abs(curvatureA), abs(curvatureB)) * centerLinearDepth;
//     o0.y = saturate(1.0 - curvature * 1024.0);
// 
//   // o0.y = 0; //NOT USED!!!
//   return;
// 
// #endif
// }