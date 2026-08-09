// ---- Created with 3Dmigoto v1.3.16 on Tue Aug 04 12:24:13 2026

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

SamplerState PS_SAMPLERS_3__s : register(s3);
SamplerState PS_SAMPLERS_4__s : register(s4);
Texture2D<float4> PS_TEXTURES_2D_0_ : register(t0); //depth
Texture2D<float4> PS_TEXTURES_2D_1_ : register(t1); //depth 1/2 res
Texture2D<float4> PS_TEXTURES_2D_6_ : register(t6); //visiblity & edges


// 3Dmigoto declarations
#define cmp -
#include "./Includes/Common.hlsl"

#if USE_GTAO == 1
#include "./Includes/XeGTAO.hlsl"
#endif

void main(
  float4 v0 : SV_Position0,
  float2 v1 : TEXCOORD0,
  out float2 o0 : SV_Target0)
{
  float4 r0,r1,r2,r3,r4;
  uint4 bitmask, uiDest;
  float4 fDest;

#if 0 /* USE_GTAO == 1 */
  r0.xy = SSAO_TEX_COORD_SCALE.zw + -SSAO_TEX_COORD_SCALE.xy;
  r0.zw = v1.xy + -r0.xy;
  r1.xy = SSAO_TEX_COORD_SCALE.yx + SSAO_TEX_COORD_SCALE.wz;
  r0.zw = r0.zw / r1.yx;
  r0.zw = floor(r0.zw);
  r0.zw = r0.zw * r1.yx + r0.xy;
  o0.xy = PS_TEXTURES_2D_6_.SampleLevel(PS_SAMPLERS_3__s, r0.zw, 0).x;


//   uint2 pixCoord = uint2(v0.xy);
// 
//   float2 depthTexSize;
//   PS_TEXTURES_2D_0_.GetDimensions(depthTexSize.x, depthTexSize.y);
//   // float2 depthTexSize = LumaSettings.SwapchainSize;
// 
//   // float2 swapchainTexSize = LumaSettings.SwapchainSize;
// 
//   GTAOConstants c = (GTAOConstants) 0;
//   c.RenderPixelSize = 1.0 / depthTexSize;
//   c.ViewportPixelSize = 1.0 / depthTexSize;
//   c.ViewportSize = depthTexSize;
//   c.NDCToViewMul = c.RenderPixelSize / PS_REG_SSAO_FRUSTUM_SCALE.zw;
//   c.NDCToViewAdd = -0.5 / PS_REG_SSAO_FRUSTUM_SCALE.zw;
//   c.NDCToViewMul_x_PixelSize = c.NDCToViewMul; // already per-pixel scaled above
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
//   // float XeGTAO_Denoise(uint2 pixCoordBase, Texture2D sourceAOTermAndEdges, SamplerState texSampler, const uniform bool finalApply, const GTAOConstants consts)
//   o0.xy = XeGTAO_Denoise(pixCoord, PS_TEXTURES_2D_6_, PS_SAMPLERS_3__s, true, c);

  return;
#else
  r0.xy = SSAO_TEX_COORD_SCALE.zw + -SSAO_TEX_COORD_SCALE.xy;
  r0.zw = v1.xy + -r0.xy;
  r1.xy = SSAO_TEX_COORD_SCALE.yx + SSAO_TEX_COORD_SCALE.wz;
  r0.zw = r0.zw / r1.yx;
  r0.zw = floor(r0.zw);
  r0.zw = r0.zw * r1.yx + r0.xy;
  r1.z = PS_TEXTURES_2D_1_.SampleLevel(PS_SAMPLERS_3__s, r0.zw, 0).x;
  r1.w = PS_TEXTURES_2D_0_.SampleLevel(PS_SAMPLERS_3__s, v1.xy, 0).x;
  r2.x = r1.w + -r1.z;
  r2.z = abs(r2.x);
  r0.xy = r0.zw + r1.yx;
  r2.y = PS_TEXTURES_2D_1_.SampleLevel(PS_SAMPLERS_3__s, r0.xw, 0).x;
  r2.w = -r2.y + r1.w;
  r3.z = abs(r2.w);
  r2.w = cmp(r3.z < r2.z);
  r2.x = r0.z;
  r3.xy = r0.xw;
  r3.xz = r2.ww ? r3.xz : r2.xz;
  r2.x = PS_TEXTURES_2D_1_.SampleLevel(PS_SAMPLERS_3__s, r0.zy, 0).x;
  r2.z = -r2.x + r1.w;
  r4.z = abs(r2.z);
  r2.z = cmp(r4.z < r3.z);
  r4.xy = r0.zy;
  r0.zw = v1.yx + -r0.wz;
  r0.zw = r0.zw / r1.xy;
  r3.xyz = r2.zzz ? r4.xyz : r3.xyz;
  r1.x = PS_TEXTURES_2D_1_.SampleLevel(PS_SAMPLERS_3__s, r0.xy, 0).x;
  r1.y = r1.w + -r1.x;
  r1.x = r1.x * r0.z;
  r1.y = cmp(abs(r1.y) < r3.z);
  r0.xy = r1.yy ? r0.xy : r3.xy;
  r1.y = r2.x * r0.z;
  r2.xz = float2(1,1) + -r0.zw;
  r0.z = r1.z * r2.x + r1.y;
  r1.x = r2.y * r2.x + r1.x;
  r0.w = r1.x * r0.w;
  r0.z = r0.z * r2.z + r0.w;
  r0.z = r1.w + -r0.z;
  r0.w = 1.33333344e-007 + r1.w;
  r0.w = 0.100000016 / r0.w;
  r0.z = abs(r0.z) * r0.w;
  r0.z = cmp(0.00048828125 < r0.z);
  r0.xy = r0.zz ? r0.xy : v1.xy;
  float2 aoUv = r0.xy;
  
  // r0.x = PS_TEXTURES_2D_6_.SampleLevel(PS_SAMPLERS_4__s, r0.xy, 0).x; //BRUH!!! Edges not even used...

  // sample AO with blur
  r0.xy = PS_TEXTURES_2D_6_.SampleLevel(PS_SAMPLERS_4__s, aoUv, 0).xy;
  if (r0.y > 0.6) { //edges
    // r0.xy += PS_TEXTURES_2D_6_.SampleLevel(PS_SAMPLERS_4__s, aoUv, 0, int2(-1, 0)).xy;
    // r0.xy += PS_TEXTURES_2D_6_.SampleLevel(PS_SAMPLERS_4__s, aoUv, 0, int2(1, 0)).xy;
    // r0.xy += PS_TEXTURES_2D_6_.SampleLevel(PS_SAMPLERS_4__s, aoUv, 0, int2(0, -1)).xy;
    // r0.xy += PS_TEXTURES_2D_6_.SampleLevel(PS_SAMPLERS_4__s, aoUv, 0, int2(0, 1)).xy;
    // r0.xy += PS_TEXTURES_2D_6_.SampleLevel(PS_SAMPLERS_4__s, aoUv, 0, int2(-1, -1)).xy;
    // r0.xy += PS_TEXTURES_2D_6_.SampleLevel(PS_SAMPLERS_4__s, aoUv, 0, int2(1, -1)).xy;
    // r0.xy += PS_TEXTURES_2D_6_.SampleLevel(PS_SAMPLERS_4__s, aoUv, 0, int2(-1, 1)).xy;
    // r0.xy += PS_TEXTURES_2D_6_.SampleLevel(PS_SAMPLERS_4__s, aoUv, 0, int2(1, 1)).xy;
    // r0.xy /= 9.0; // average the 9 samples

    // only 4 additional
    r0.xy += PS_TEXTURES_2D_6_.SampleLevel(PS_SAMPLERS_4__s, aoUv, 0, int2(-1, 0)).xy;
    r0.xy += PS_TEXTURES_2D_6_.SampleLevel(PS_SAMPLERS_4__s, aoUv, 0, int2(1, 0)).xy;
    r0.xy += PS_TEXTURES_2D_6_.SampleLevel(PS_SAMPLERS_4__s, aoUv, 0, int2(0, -1)).xy;
    r0.xy += PS_TEXTURES_2D_6_.SampleLevel(PS_SAMPLERS_4__s, aoUv, 0, int2(0, 1)).xy;
    r0.xy /= 5.0; // average the 5 samples (original + 4 additional)
  }

  r0.x = saturate(r0.x); //not possible, but just in case
  r0.x = pow(r0.x, PS_REG_SSAO_PARAMS.x /* * DVS8 */); //strength
  r0.x = max(PS_REG_SSAO_PARAMS.y, r0.x);
  o0.xy = r0.xx;
  return;

//   // The AO buffer (t6) is rendered at half resolution using a per-pixel dithered kernel (see ao0), so each
//   // 2x2 block of full-res pixels maps to 4 different half-res taps, each computed with a different dither
//   // rotation. The original resolve only ever point-sampled a single one of those taps (either the bilinearly
//   // sampled v1.xy tap, or - near depth discontinuities - the single closest-depth tap), so the dither pattern
//   // from ao0 was never actually blended away here. Instead, always blend all 4 taps (weighted by their own
//   // edge/curvature confidence from ao0's y channel), and only fade towards a single nearest-depth tap - with a
//   // soft ramp instead of a hard cutoff - to avoid bleeding AO across genuine depth discontinuities.
// 
//   float2 cellOrigin = SSAO_TEX_COORD_SCALE.zw - SSAO_TEX_COORD_SCALE.xy;
//   float2 cellSize = SSAO_TEX_COORD_SCALE.yx + SSAO_TEX_COORD_SCALE.wz;
// 
//   float2 cellCoord = floor((v1.xy - cellOrigin) / cellSize.yx);
//   float2 tap0UV = cellCoord * cellSize.yx + cellOrigin; // (0,0) corner of the 2x2 half-res tap group
//   float2 tapXUV = tap0UV + float2(cellSize.y, 0); // (1,0)
//   float2 tapYUV = tap0UV + float2(0, cellSize.x); // (0,1)
//   float2 tapXYUV = tap0UV + cellSize.yx; // (1,1)
// 
//   float tap0Depth = PS_TEXTURES_2D_1_.SampleLevel(PS_SAMPLERS_3__s, tap0UV, 0).x;
//   float tapXDepth = PS_TEXTURES_2D_1_.SampleLevel(PS_SAMPLERS_3__s, tapXUV, 0).x;
//   float tapYDepth = PS_TEXTURES_2D_1_.SampleLevel(PS_SAMPLERS_3__s, tapYUV, 0).x;
//   float tapXYDepth = PS_TEXTURES_2D_1_.SampleLevel(PS_SAMPLERS_3__s, tapXYUV, 0).x;
//   float centerDepth = PS_TEXTURES_2D_0_.SampleLevel(PS_SAMPLERS_3__s, v1.xy, 0).x;
// 
//   // Position of the current pixel within the 2x2 tap group; used both to bilinearly reconstruct the depth
//   // (to detect discontinuities) and to bilinearly blend the AO taps themselves.
//   float fracY = (v1.y - tap0UV.y) / cellSize.x;
//   float fracX = (v1.x - tap0UV.x) / cellSize.y;
// 
//   // Find the single closest-depth tap, used as a fallback on real depth discontinuities.
//   float2 nearestTapUV = tap0UV;
//   float nearestAbsDiff = abs(centerDepth - tap0Depth);
//   float absDiffX = abs(centerDepth - tapXDepth);
//   if (absDiffX < nearestAbsDiff) { nearestTapUV = tapXUV; nearestAbsDiff = absDiffX; }
//   float absDiffY = abs(centerDepth - tapYDepth);
//   if (absDiffY < nearestAbsDiff) { nearestTapUV = tapYUV; nearestAbsDiff = absDiffY; }
//   float absDiffXY = abs(centerDepth - tapXYDepth);
//   if (absDiffXY < nearestAbsDiff) { nearestTapUV = tapXYUV; nearestAbsDiff = absDiffXY; }
// 
//   // Reconstruct what the depth "should" be at this pixel by bilinearly blending the 4 tap depths, and compare
//   // it against the real depth; a large mismatch means the taps straddle a depth discontinuity.
//   float col0Depth = lerp(tap0Depth, tapYDepth, fracY);
//   float col1Depth = lerp(tapXDepth, tapXYDepth, fracY);
//   float bilinearDepth = lerp(col0Depth, col1Depth, fracX);
// 
//   float centerLinearDepth = 0.100000016 / (1.33333344e-007 + centerDepth);
//   float relDepthError = abs(centerDepth - bilinearDepth) * centerLinearDepth;
// 
//   const float EDGE_THRESHOLD = 0.00048828125; // matches the original hard cutoff
//   const float EDGE_TRANSITION_RANGE = EDGE_THRESHOLD * 3.0;
//   float edgeBlend = saturate((relDepthError - EDGE_THRESHOLD) / EDGE_TRANSITION_RANGE);
// 
//   float2 tap0AO = PS_TEXTURES_2D_6_.SampleLevel(PS_SAMPLERS_4__s, tap0UV, 0).xy;
//   float2 tapXAO = PS_TEXTURES_2D_6_.SampleLevel(PS_SAMPLERS_4__s, tapXUV, 0).xy;
//   float2 tapYAO = PS_TEXTURES_2D_6_.SampleLevel(PS_SAMPLERS_4__s, tapYUV, 0).xy;
//   float2 tapXYAO = PS_TEXTURES_2D_6_.SampleLevel(PS_SAMPLERS_4__s, tapXYUV, 0).xy;
//   float2 nearestAO = PS_TEXTURES_2D_6_.SampleLevel(PS_SAMPLERS_4__s, nearestTapUV, 0).xy;
// 
//   // Weight each tap not just by its bilinear position but also by its own edge/curvature confidence (the AO
//   // buffer's y channel), so taps that were themselves near a discontinuity in ao0 contribute less here.
//   float weight0 = (1.0 - fracX) * (1.0 - fracY) * tap0AO.y;
//   float weightX = fracX * (1.0 - fracY) * tapXAO.y;
//   float weightY = (1.0 - fracX) * fracY * tapYAO.y;
//   float weightXY = fracX * fracY * tapXYAO.y;
//   float weightSum = weight0 + weightX + weightY + weightXY;
// 
//   float bilinearVisibility = (weightSum > 1e-5)
//     ? (tap0AO.x * weight0 + tapXAO.x * weightX + tapYAO.x * weightY + tapXYAO.x * weightXY) / weightSum
//     : lerp(lerp(tap0AO.x, tapYAO.x, fracY), lerp(tapXAO.x, tapXYAO.x, fracY), fracX);
// 
//   float visibility = lerp(bilinearVisibility, nearestAO.x, edgeBlend);
//   visibility = saturate(visibility);
//   visibility = pow(visibility, PS_REG_SSAO_PARAMS.x); //strength
//   o0.xy = max(PS_REG_SSAO_PARAMS.yy, visibility.xx);
//   return;
#endif
}