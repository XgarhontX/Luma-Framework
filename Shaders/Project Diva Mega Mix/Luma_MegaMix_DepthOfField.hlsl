// main reference, for disc: https://github.com/keijiro/KinoBokeh
// straight forward full res DoF hype: https://github.com/ninjamica/Painted-DOF/blob/main/DOF_Paint.fx
// for hexgonal (not implemented): https://github.com/zigguratvertigo/HexBokehBlur/blob/master/HexagonalBokehBlur.rfx

cbuffer PsCommon : register(b0)
{
  float4 g_depth_params : packoffset(c0);
  float4 g_spread_scale : packoffset(c1);
  float4 g_depth_params2 : packoffset(c2);
  float4 g_texcoord_offset_for_upsample : packoffset(c3);
  int4 g_dof_param : packoffset(c4);

// g_depth_params 19.99983, 0.00017, 0.00, 0.00 (0 float4)
// g_spread_scale 27193.05664, 9064.35254, 0.33333, 3.00 (16 float4)
// g_depth_params2 3.76145, 1.59632, -0.01329, 2.26034 (32 float4)
// g_texcoord_offset_for_upsample 0.00078, 0.00139, 0.00078, 0.00139 (48 float4)
// g_dof_param 20, 8, 7, 8 (64 int4)
}

#include "./Includes/Common.hlsl"

#define COC_MAX 0.600 // vanilla faithful fudge
#define COC_FUDGE 4.000 * 0.005 // vanilla faithful fudge

#define BLUR_IN_LINEAR 1 // trade flickering for really good bokeh

#define KERNEL_LENGTH 43
#define KERNEL_LENGTH_1ST_RING 8
static const float2 KERNEL[KERNEL_LENGTH] = { // "KERNEL_LARGE" 4 rings, 7 points per ring
  {          0,           0},
  { 0.36363637,           0},
  { 0.22672357,  0.28430238},
  {-0.08091671,  0.35451925},
  {-0.32762504,  0.15777594},
  {-0.32762504, -0.15777591},
  {-0.08091656, -0.35451928},
  { 0.22672352,  -0.2843024},
  {  0.6818182,           0},
  {   0.614297,  0.29582983},
  { 0.42510667,   0.5330669},
  { 0.15171885,   0.6647236},
  {-0.15171883,   0.6647236},
  { -0.4251068,  0.53306687},
  {  -0.614297,  0.29582986},
  { -0.6818182,           0},
  {  -0.614297, -0.29582983},
  {-0.42510656, -0.53306705},
  {-0.15171856, -0.66472363},
  {  0.1517192,  -0.6647235},
  {  0.4251066, -0.53306705},
  {   0.614297, -0.29582983},
  {        1.0,           0},
  {  0.9555728,   0.2947552},
  { 0.82623875,   0.5633201},
  {  0.6234898,   0.7818315},
  { 0.36534098,  0.93087375},
  {    0.07473,   0.9972038},
  {-0.22252095,   0.9749279},
  {-0.50000006,   0.8660254},
  {-0.73305196,   0.6801727},
  {-0.90096885,  0.43388382},
  {-0.98883086,  0.14904208},
  { -0.9888308, -0.14904249},
  {-0.90096885, -0.43388376},
  {-0.73305184,  -0.6801728},
  { -0.4999999, -0.86602545},
  {  -0.222521,  -0.9749279},
  { 0.07473029, -0.99720377},
  { 0.36534148,  -0.9308736},
  {  0.6234897,  -0.7818316},
  {  0.8262388,    -0.56332},
  {  0.9555729, -0.29475483},
};

// https://www.desmos.com/calculator/eudc3yupeo
float CalculateBlurFactor(float linearDepth, bool isFarOnly = false, bool isParamW = true, bool isNearNegative = false, bool isCustom = false)
{
  float4 params = g_depth_params2;
  float x = params.x - linearDepth;

  if (!isFarOnly) x = abs(x);
  else x = -x;

  x -= params.y;
  x = max(0, x);
  x *= x;
  x *= params.z;
  x *= 1.44269502;
  x = exp2(x);
  x = 1 - x;

  if (isParamW) x *= params.w; // final multiplier, gets clamped later

  if (isCustom) // vanilla faithful fudge
  {
    x *= 0.3; 
    x = x * x * x * x;
    x = clamp(x, 0, COC_MAX);
  }

  if (isNearNegative && linearDepth < params.x) x = -x;

  return x;
}

float LinearizeDepth(float depth) { return rcp(depth * g_depth_params.x + g_depth_params.y); }

//////////////////////////////////////////////////////////////////////////////////////////////

SamplerState s_point  : register(s0);
SamplerState s_linear : register(s1);
Texture2D<float4> t_color    : register(t3);
Texture2D<float>  t_depth    : register(t4);
Texture2D<float>  t_coc      : register(t5);
Texture2D<float4> t_halfprev : register(t5);

// https://github.com/keijiro/KinoBokeh/blob/master/Assets/Kino/Bokeh/Shader/Prefilter.cginc
void Prefilter( // aka Downsample
  float4 v0 : SV_POSITION0, // pix pos
  float4 v1 : TEXCOORD0, // center: xy
  out float4 o0 : SV_Target0 // half res rgba16f
)
{
  float2 texSizeMain = LumaSettings.RenderSize;
  float2 pixSizeMain = LumaSettings.RenderInvSize;
  float2 texSizeHalf = LumaSettings.RenderSize / 2;
  float2 pixSizeHalf = LumaSettings.RenderInvSize * 2;
  uint2  pixPosHalf  = (uint2)v0.xy;
  uint2  pixPosMain  = pixPosHalf * 2;

  // sample scene quad
  float3 cTL = max(0, t_color.Load(uint3(pixPosMain, 0)).xyz);
  float3 cTR = max(0, t_color.Load(uint3(pixPosMain + uint2(1, 0), 0)).xyz);
  float3 cBL = max(0, t_color.Load(uint3(pixPosMain + uint2(0, 1), 0)).xyz);
  float3 cBR = max(0, t_color.Load(uint3(pixPosMain + uint2(1, 1), 0)).xyz);

  // gamma decode (can be flickery, but more proper PBR)
  #if BLUR_IN_LINEAR
    cTL = pow(cTL, 2.2);
    cTR = pow(cTR, 2.2);
    cBL = pow(cBL, 2.2);
    cBR = pow(cBR, 2.2);
  #endif

  // gather depth quad
  float4 dGather = t_depth.Gather(s_point, v1.xy);
  float dTL = LinearizeDepth(dGather.x);
  float dTR = LinearizeDepth(dGather.y);
  float dBL = LinearizeDepth(dGather.z);
  float dBR = LinearizeDepth(dGather.w);

  // coc
  float cocTL = CalculateBlurFactor(dTL, false, true, true, true) * COC_FUDGE;
  float cocTR = CalculateBlurFactor(dTR, false, true, true, true) * COC_FUDGE;
  float cocBL = CalculateBlurFactor(dBL, false, true, true, true) * COC_FUDGE;
  float cocBR = CalculateBlurFactor(dBR, false, true, true, true) * COC_FUDGE;
  // float coc = dot(float4(cocTL, cocTR, cocBL, cocBR), 0.25f); //(cocTL + cocTR + cocBL + cocBR) / 4; // THIS SUCKS! bleeds emissives everywhere!!!
  float coc = min(min(cocTL, cocTR), min(cocBL, cocBR)); // favor no bleeding, reconstruct/fill later

  float cocTLAbs = abs(cocTL);
  float cocTRAbs = abs(cocTR);
  float cocBLAbs = abs(cocBL);
  float cocBRAbs = abs(cocBR);
  // float coc = min(min(cocTLAbs, cocTRAbs), min(cocBLAbs, cocBRAbs)); // favor no bleeding

  // weights premultiply
  float wTL = saturate(cocTLAbs * 1/COC_MAX);
  float wTR = saturate(cocTRAbs * 1/COC_MAX);
  float wBL = saturate(cocBLAbs * 1/COC_MAX);
  float wBR = saturate(cocBRAbs * 1/COC_MAX);

  #if BLUR_IN_LINEAR // TODO: idk, it still flickers. we need that TAA action
    // Apply luma weights to reduce flickering. Inspired by goo.gl/j1fhLe goo.gl/mfuZ4h
    wTL *= 1 / (GetLuminance(cTL) + 1);
    wTR *= 1 / (GetLuminance(cTR) + 1);
    wBL *= 1 / (GetLuminance(cBL) + 1);
    wBR *= 1 / (GetLuminance(cBR) + 1);
  #endif
  
  // color weighted
  cTL *= wTL;
  cTR *= wTR;
  cBL *= wBL;
  cBR *= wBR;
  float3 colorTotal = safeDivision((cTL + cTR + cBL + cBR), dot(float4(wTL, wTR, wBL, wBR), 1), 0); /* (wTL + wTR + wBL + wBR) */;

  // premultiply coc again (VERY NEEDED to reduce bleeding)
  colorTotal *= smoothstep(0, pixSizeHalf.y * 2, abs(coc));

  // out
  o0 = float4(colorTotal, coc);
}

// https://github.com/keijiro/KinoBokeh/blob/master/Assets/Kino/Bokeh/Shader/DiskKernel.cginc
void BokehSim(float4 v0, float4 v1, out float4 o0, bool is2ndPass)
{
  float2 texSizeMain = LumaSettings.RenderSize;
  float2 pixSizeMain = LumaSettings.RenderInvSize;
  float2 texSizeHalf = LumaSettings.RenderSize / 2;
  float2 pixSizeHalf = LumaSettings.RenderInvSize * 2;
  uint2  pixPosHalf  = (uint2)v0.xy;
  uint2  pixPosMain  = pixPosHalf * 2;
  float  aspectRatioInv = texSizeMain.y / texSizeMain.x;

  // center
  float4 samp0 = t_halfprev.SampleLevel(s_point, v1.xy, 0); // TODO: point or linear?

  float4 bgAcc = 0; // far field bokeh
  float4 fgAcc = 0; // near field bokeh

  const uint sampleCount = KERNEL_LENGTH;
  [unroll] for (uint si = 0; si < sampleCount; si++)
  {
    float2 disp = KERNEL[si] * samp0.a * COC_MAX;
    float dist = length(disp);

    float2 duv = float2(disp.x * aspectRatioInv, disp.y);
    float4 samp = t_halfprev.SampleLevel(s_linear, v1.xy + duv, 0);

    // BG: Compare CoC of the current sample and the center sample and select smaller one.
    float bgCoC = max(min(samp0.a, samp.a), 0);

    // Compare the CoC to the sample distance. Add a small margin to smooth out.
    const float margin = pixSizeHalf.y * 2;
    float bgWeight = saturate((bgCoC   - dist + margin) / margin);
    float fgWeight = saturate((-samp.a - dist + margin) / margin);

    // Cut influence from focused areas because they're darkened by CoC premultiplying. This is only needed for near field.
    fgWeight *= step(pixSizeHalf.y, -samp.a);

    // Accumulation
    bgAcc += float4(samp.rgb, 1) * bgWeight;
    fgAcc += float4(samp.rgb, 1) * fgWeight;
  }

  // Get the weighted average.
  bgAcc.rgb = safeDivision(bgAcc.rgb, bgAcc.a, 1);
  fgAcc.rgb = safeDivision(fgAcc.rgb, fgAcc.a, 1);

  // BG: Calculate the alpha value only based on the center CoC. This is a rather aggressive approximation but provides stable results.
  bgAcc.a = smoothstep(pixSizeHalf.y, pixSizeHalf.y * 2, samp0.a);

  // FG: Normalize the total of the weights.
  fgAcc.a *= PI / sampleCount;

  // Alpha premultiplying
  float3 rgb = 0;
  rgb = lerp(rgb, bgAcc.rgb, saturate(bgAcc.a));
  rgb = lerp(rgb, fgAcc.rgb, saturate(fgAcc.a));

  // Combined alpha value
  float alpha = (1 - saturate(bgAcc.a)) * (1 - saturate(fgAcc.a));

  o0 = float4(rgb, alpha);
}

void BokehSim0(
  float4 v0 : SV_POSITION0, // pix pos
  float4 v1 : TEXCOORD0, // center: xy
  out float4 o0 : SV_Target0
)
{
  float2 texSizeMain = LumaSettings.RenderSize;
  float2 pixSizeMain = LumaSettings.RenderInvSize;
  float2 texSizeHalf = LumaSettings.RenderSize / 2;
  float2 pixSizeHalf = LumaSettings.RenderInvSize * 2;

  // o0 = t_halfprev.Load(int3(v0.xy, 0)); // debug passthrough
  BokehSim(v0, v1, o0, false); // do BOKEH!
}

// https://github.com/keijiro/KinoBokeh/blob/master/Assets/Kino/Bokeh/Shader/Composition.cginc
float4 Sample9Tent(float2 uv, float2 pixelSize)
{
  // 9-tap tent filter
  float4 duv = pixelSize.xyxy * float4(1, 1, -1, 0);
  float4 acc;

  acc =  t_halfprev.SampleLevel(s_linear, uv - duv.xy, 0)    ;
  acc += t_halfprev.SampleLevel(s_linear, uv - duv.wy, 0) * 2;
  acc += t_halfprev.SampleLevel(s_linear, uv - duv.zy, 0)    ;
  acc += t_halfprev.SampleLevel(s_linear, uv + duv.zw, 0) * 2;
  acc += t_halfprev.SampleLevel(s_linear, uv, 0)          * 4;
  acc += t_halfprev.SampleLevel(s_linear, uv + duv.xw, 0) * 2;
  acc += t_halfprev.SampleLevel(s_linear, uv + duv.zy, 0)    ;
  acc += t_halfprev.SampleLevel(s_linear, uv + duv.wy, 0) * 2;
  acc += t_halfprev.SampleLevel(s_linear, uv + duv.xy, 0)    ;

  return acc / 16;
}

void BokehSim1(
  float4 v0 : SV_POSITION0, // pix pos
  float4 v1 : TEXCOORD0, // center: xy
  out float4 o0 : SV_Target0
)
{
  float2 texSizeMain = LumaSettings.RenderSize;
  float2 pixSizeMain = LumaSettings.RenderInvSize;
  float2 texSizeHalf = LumaSettings.RenderSize / 2;
  float2 pixSizeHalf = LumaSettings.RenderInvSize * 2;

  // o0 = t_halfprev.Load(int3(v0.xy, 0));
  // BokehSim(v0, v1, o0, true);
  o0 = Sample9Tent(v1.xy, pixSizeHalf); // expand blur, so reconstruct is easier
  // #if BLUR_IN_LINEAR
  //   o0.xyz = pow(o0.xyz, 1/2.2);
  // #endif
}

// https://github.com/keijiro/KinoBokeh/blob/master/Assets/Kino/Bokeh/Shader/Composition.cginc
void Upsample(
  float4 v0 : SV_POSITION0, // pix pos
  float4 v1 : TEXCOORD0, // center: xy
  out float4 o0 : SV_Target0
) 
{
  float2 texSizeMain = LumaSettings.RenderSize;
  float2 pixSizeMain = LumaSettings.RenderInvSize;
  float2 texSizeHalf = LumaSettings.RenderSize / 2;
  float2 pixSizeHalf = LumaSettings.RenderInvSize * 2;
  uint2  pixPosMain  = (uint2)v0.xy;
  uint2  pixPosHalf  = pixPosMain * 2;

  // center
  float4 cs = t_color.Load(int3(v0.xy, 0));
  #if BLUR_IN_LINEAR
    cs.xyz = pow(cs.xyz, 2.2);
  #endif
  o0 = cs;

  float depth = LinearizeDepth(t_depth.Load(int3(v0.xy, 0)));

  // upsample
  float4 cb = t_halfprev.SampleLevel(s_linear, v1.xy, 0);
  // float4 cb = Sample9Tent(v1.xy, pixSizeHalf);

//   // combine
//   float3 rgb = cb.xyz;
//   rgb += cs.xyz * cb.w;
// 
//   // reconstruction (only fixes half the cases for edge pixels, needs better spatial aware)
//   float coc = CalculateBlurFactor(depth, false, false, false, false) /* * COC_FUDGE */;
//   if (cb.a < 1 && abs(coc) <= 0.00001) rgb = cs.xyz; // edge (literally) case

  // reconstruction cheese (AI helped)
  float A = saturate(1.0 - cb.a); // blurred coverage
  float3 B = cb.rgb / max(A, 1e-5); // unpremultiply
  // float3 rgb = B; // debug

  // mimic Prefilter coc as best as possible (AI helped)
  float coc = CalculateBlurFactor(depth, false, true, true, true) * COC_FUDGE;
  float radiusPixels = abs(coc) * COC_MAX * texSizeMain.y;

  // mask feather (AI helped)
  const float radiusStart = 0.0; // fudge
  const float radiusEnd = 16.0 * texSizeMain.y / 2160.0; // fudge, based on 4k
  const float coverageConfidence = 0.2; // fudge
  float mask = smoothstep(radiusStart, radiusEnd, radiusPixels);
  mask *= smoothstep(1e-5, coverageConfidence, A);
  float3 rgb = lerp(cs.rgb, B, mask);
  
  // out
  #if BLUR_IN_LINEAR
    rgb = pow(rgb, 1/2.2);
  #endif
  o0 = half4(rgb, cs.a);
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// void CalcCoC(
//   float4 v0 : SV_POSITION0, // pix pos
//   float4 v1 : TEXCOORD0, // center: xy
//   out float o0 : SV_Target0 // t_coc
// )
// {
//   float2 texSize = LumaSettings.RenderSize;
//   float2 pixSize = LumaSettings.RenderInvSize;
// 
//   float depth = LinearizeDepth(t_depth.Load(int3(v0.xy, 0)));
//   float coc = CalculateBlurFactor(depth, false, true, true); // TODO: will prob need fudge
//   coc = clamp(coc, 0, 1.26); // clamp (to not expose sparse KERNEL) (to not wreck VRAM locality)
//   coc *= 12;
//   o0 = coc;
// }
// 
// void BlurEffect(
//   float4 v0 : SV_POSITION0,
//   float4 v1 : TEXCOORD0,
//   out float4 o0 : SV_Target0
// )
// {
//   // get center
//   float4 col = t_color.Load(int3(v0.xy, 0));
//   o0 = col;
// 
//   float coc = t_coc.Load(int3(v0.xy, 0));
//   // o0.xyz = coc; return; // debug 
//   if (/* abs */ (coc) <= 0.0001)
//   {
//     // o0.xyz = float3(1,0,0);
//     return;
//   }
// 
//   float depth = LinearizeDepth(t_depth.Load(int3(v0.xy, 0)));
// 
//   // spread
//   float2 texSize = LumaSettings.RenderSize;
//   float2 pixSize = LumaSettings.RenderInvSize;
//   float2 spread = pixSize * coc;
// 
//   // loop
//   float3 aCol = col.xyz * coc;
//   float aCoc = coc;
// 	[unroll] for (int i = 1; i < KERNEL_LENGTH; i++) // start i = 1 to skip center sample
//   {
//     float2 texcoordCurr = KERNEL[i] * spread + v1.xy;
// 
//     float3 colCurr = t_color.Sample(s_point, texcoordCurr).rgb; // MUST BE POINT! else, linear will leak
//     float cocCurr = t_coc.Sample(s_point, texcoordCurr).r;
// 
//     aCol += colCurr * cocCurr;
//     aCoc += cocCurr;
//   }
//   aCol = abs(aCol); // clean
//   aCol /= aCoc;
//   // g_spread_scale.z controls final alpha blend i think. it sucks! not how dof works.
// 
//   o0.xyz = aCol;
// }

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// // Presort
// SamplerState g_depth_sampler_s : register(s0);
// SamplerState g_color_sampler_s : register(s1);
// Texture2D<float> g_depth : register(t0);  // full res
// Texture2D<float4> g_color : register(t1); // full res
// 
// // Blur
// // that one disc pattern, dont know when first used, but Jiminez 2014 / CoD:AW for sure https://www.desmos.com/calculator/cyn6ok0dor
// cbuffer Offset : register(b1)
// {
//   float4 g_offsets[25] : packoffset(c0);
// }
// static const float4 g_offsets_static[25] = {
//   {-6.36396, -6.36396, -4.50, -7.79423     },
//   {-2.32937, -8.69333, 1.57361E-06, -9.00  },
//   {2.32938, -8.69333, 4.50, -7.79423       },
//   {6.36396, -6.36396, -7.79423, -4.50      },
//   {-4.24264, -4.24264, -2.2961, -5.54328   },
//   {1.04907E-06, -6.00, 2.2961, -5.54328    },
//   {4.24264, -4.24264, 7.79423, -4.50       },
//   {-8.69333, -2.32937, -5.54328, -2.2961   },
//   {-2.12132, -2.12132, 5.24537E-07, -3.00  },
//   {2.12132, -2.12132, 5.54328, -2.2961     },
//   {8.69333, -2.32937, -9.00, -7.86805E-07  },
//   {-6.00, -5.24537E-07, -3.00, -2.62268E-07},
//   {0.00, 0.00, 3.00, 0.00                  },
//   {6.00, 0.00, 9.00, 0.00                  },
//   {-8.69333, 2.32937, -5.54328, 2.2961     },
//   {-2.12132, 2.12132, -2.62268E-07, 3.00   },
//   {2.12132, 2.12132, 5.54328, 2.2961       },
//   {8.69333, 2.32937, -7.79423, 4.50        },
//   {-4.24264, 4.24264, -2.2961, 5.54328     },
//   {-5.24537E-07, 6.00, 2.2961, 5.54328     },
//   {4.24264, 4.24264, 7.79423, 4.50         },
//   {-6.36396, 6.36396, -4.50, 7.79423       },
//   {-2.32937, 8.69333, -7.86805E-07, 9.00   },
//   {2.32937, 8.69333, 4.50, 7.79423         },
//   {6.36396, 6.36396, 0.00, 0.00            },
// };
// 
// SamplerState g_presort_sampler_s : register(s0);
// // SamplerState g_color_sampler_s : register(s1);
// SamplerState g_tile_sampler_s : register(s2);
// Texture2D<float4> g_presort : register(t0); // 1/2 full res
// // Texture2D<float4> g_color : register(t1); // 1/2 full res
// Texture2D<float4> g_tile : register(t2); // 192x108 (trash, superceded by Gather() below)
// 
// // Resolve
// SamplerState g_filtered_rgb_sampler_s : register(s0);
// SamplerState g_filtered_a_sampler_s : register(s1);
// // SamplerState g_tile_sampler_s : register(s2);
// SamplerState g_full_res_color_sampler_s : register(s3);
// SamplerState g_full_res_depth_sampler_s : register(s4);
// Texture2D<float3> g_filtered_rgb : register(t0);
// Texture2D<float>  g_filtered_a : register(t1);
// // Texture2D<float2> g_tile : register(t2);
// Texture2D<float4> g_full_res_color : register(t3);
// Texture2D<float>  g_full_res_depth : register(t4);
// Texture2D<float4> g_presort_5 : register(t5);
// 
// #define cmp -
// 
// #define BLUR_MULTIPLIER 1
// 
// //////////////////////////////////////////////////////////////////////////////////////////////
// 
// // 0.5x downsample color
// // and spread scale calcuation (CoC stuff?)
// void presort(
//   float4 v0 : SV_POSITION0,
//   float4 v1 : TEXCOORD0,
//   // r11g11b10f (bruh, they use this here but not anywhere else?)
//   out float3 o0 : SV_Target0, // downsample 0.5x color (g_color)
//   out float4 o1 : SV_Target1 // x: blurred downsampled color, y: 0, z:  (g_presort)
// )
// {
//   // KERNEL texcoord offsets, forms diamond pattern https://www.desmos.com/calculator/cyn6ok0dor
//   const float4 icb[] = { { 0.000781, 0, 0.000781, 0},
//                          { 0.000241, -0.001321, 0, -0.001389},
//                          { 0.000241, 0.001321, -0.000781, 0},
//                          { -0.000632, -0.000816, 0, 0.001389},
//                          { -0.000632, 0.000816, 0.000781, 0},
//                          { -0.000552, -0.000982, -0.000241, -0.001203}, // start of max quality offsets (xy)
//                          { 0, -0.001389, -0.000241, 0.001203},
//                          { 0.000552, -0.000982, 0, 0},
//                          { -0.000781, 0, 0, 0},
//                          { 0.000781, 0, 0, 0},
//                          { -0.000552, 0.000982, 0, 0},
//                          { 0, 0.001389, 0, 0},
//                          { 0.000552, 0.000982, 0, 0} };
//   float4 r0,r1,r2,r3,r4;
//   uint4 bitmask, uiDest;
//   float4 fDest;
// 
//   // size
//   float2 texSize = LumaSettings.RenderSize;
//   float2 pixSize = LumaSettings.RenderInvSize;
// 
//   // depth center (box min biased which the rest of CoC calculations will use)
//   float4 depthCenterGather = g_depth.Gather(g_depth_sampler_s, v1.xy);
//   float depthCenter = min(depthCenterGather.x, min(depthCenterGather.y, min(depthCenterGather.z, depthCenterGather.w)));
//   float depthCenterLinear = rcp(depthCenter * g_depth_params.x + g_depth_params.y);
// 
//   // blur factor
//   float blurFactor = CalculateBlurFactor(depthCenterLinear, g_depth_params2);
//   float blurFactorForOffset = 0.333333343 * blurFactor;
// 
//   // o1.y: min-biased blur factor
//   o1.y = blurFactor;
// 
//   // o1.w: max-biased blur factor (used but Blur to get delta to min-biased as weight to avoid halos/outlines)
//   {
//     float depthCenterMax = max(depthCenterGather.x, max(depthCenterGather.y, max(depthCenterGather.z, depthCenterGather.w)));
//     float depthCenterMaxLinear = rcp(depthCenterMax * g_depth_params.x + g_depth_params.y);
//     o1.w = CalculateBlurFactor(depthCenterMaxLinear, g_depth_params2);
//   }
// 
//   // loop init: center color
//   float3 aColor = g_color.SampleLevel(g_color_sampler_s, v1.xy, 0).xyz;
//   float aWeight = 1;
// 
//   // loop (original highest quality 8-tap)
//   [unroll] for (int i = 0; i < 8; i++)
//   {
//     // texcoord offset (based on KERNEL & blur factor) https://www.desmos.com/calculator/cyn6ok0dor
//     float2 texCoordCurr = icb[i + 5].xy * blurFactorForOffset + v1.xy;
// 
//     // depth at current texcoord
//     float4 depthGather = g_depth.Gather(g_depth_sampler_s, texCoordCurr);
//     float depth = min(depthGather.x, min(depthGather.y, min(depthGather.z, depthGather.w)));
//     float depthLinear = rcp(depth * g_depth_params.x + g_depth_params.y);
// 
//     // higher weight if depth similar
//     float delta = abs(depthLinear - depthCenterLinear);
//     // delta *= 16; // bias faster decay
//     float weight = 1 / (1 + delta); // decay
// 
//     // accumulate
//     aColor += g_color.SampleLevel(g_color_sampler_s, texCoordCurr, 0).xyz * weight;
//     aWeight += weight;
//   }
// 
//   // o0: weighted avg color
//   float3 finalColor = aColor / aWeight;
//   finalColor = pow(abs(finalColor), 2.2); // gamma decode (linearize)
//   o0.xyz = finalColor;
// 
//   // // box blur color
//   // float3 c0 = g_color.SampleLevel(g_color_sampler_s, v1.xy, 0).xyz;
//   // float3 c1 = g_color.SampleLevel(g_color_sampler_s, v1.xy + float2(pixSize.x, 0), 0).xyz;
//   // float3 c2 = g_color.SampleLevel(g_color_sampler_s, v1.xy + float2(0, pixSize.y), 0).xyz;
//   // float3 c3 = g_color.SampleLevel(g_color_sampler_s, v1.xy + float2(pixSize.x, pixSize.y), 0).xyz;
//   // float3 color = (c0 + c1 + c2 + c3) * 0.25;
//   // color = pow(abs(color), 2.2); // gamma decode (linearize)
//   // o0 = color;
// 
//   // o1: blur factor encoded incomplete radius precompute
//   float blurFactorEncoded = blurFactor * blurFactor;
//   blurFactorEncoded = max(0.5, blurFactorEncoded);
//   blurFactorEncoded *= 3.14159274;
//   blurFactorEncoded = rcp(blurFactorEncoded);
//   o1.z = blurFactorEncoded;
// 
//   o1.x = g_spread_scale.z * blurFactor; // raw blur factor * some settings fudge scaler
// }
// 
// //////////////////////////////////////////////////////////////////////////////////////////////
// 
// // a sample tap
// void SampleBlur(float2 texCoord, float2 scaledTexcoordOffset, float blurFactorCenter, out float3 weightedColor, out float colorWeight, out float3 areaWeightedColor, out float areaWeight) 
// {
//   float3 sampleColor = g_color.SampleLevel(g_color_sampler_s, texCoord, 0).xyz;
//   float4 presort = g_presort.SampleLevel(g_presort_sampler_s, texCoord, 0).xyzw;
// 
//   float blur = presort.x;
//   blur *= g_spread_scale.w;
//   blur = min(8, blur);
// 
//   float scaledTexcoordOffsetLength = length(scaledTexcoordOffset);
//   float scaledTexcoordOffsetLengthAdjusted = blur * g_spread_scale.z -scaledTexcoordOffsetLength;
//   scaledTexcoordOffsetLengthAdjusted = saturate(1 + scaledTexcoordOffsetLengthAdjusted);
// 
//   float spatialWeight = scaledTexcoordOffsetLength <= 1 // hard knee curve thing. x^4 is pretty much best
//     ? scaledTexcoordOffsetLengthAdjusted * scaledTexcoordOffsetLengthAdjusted * scaledTexcoordOffsetLengthAdjusted * scaledTexcoordOffsetLengthAdjusted
//     : scaledTexcoordOffsetLengthAdjusted;
// 
//   // avoid haloing/outlines (NEW)
//   float blurFactorCurr = presort.w; // REQUIRES: max-biased blurFactor
//   float blurFactorCurrDiff = blurFactorCenter - blurFactorCurr;
//   // blurFactorCurrDiff = abs(blurFactorCurrDiff); // reduce either dir
//   blurFactorCurrDiff = max(0, blurFactorCurrDiff); // reduce only if closer
//   blurFactorCurrDiff *= blurFactorCurrDiff; // easing fudge
//   blurFactorCurrDiff *= 0.32; // bias fudge
//   float blurFactorWeight = exp(-blurFactorCurrDiff); // decay
// 
//   colorWeight = spatialWeight * presort.y * blurFactorWeight;
//   weightedColor = sampleColor * colorWeight;
//   areaWeight = spatialWeight * presort.z * blurFactorWeight;
//   areaWeightedColor = sampleColor * areaWeight;
// }
// 
// void blur(
//   float4 v0 : SV_POSITION0,
//   float4 v1 : TEXCOORD0, // xy is center, zw is g_tile (though it really doesn't matter)
//   out float3 o0 : SV_Target0,
//   out float o1 : SV_Target1
// )
// {
//   float4 r0,r1,r2,r3,r4,r5,r6,r7,r8;
//   uint4 bitmask, uiDest;
//   float4 fDest;
// 
//   // verify g_offsets is always the same
// #if DEVELOPMENT
//   bool verifyA = abs(g_offsets[0].x - -6.36396) < 1e-6;
//   bool verifyB = abs(g_offsets[5].x - 1.04907E-06) < 1e-6;
//   bool verifyC = abs(g_offsets[24].x - 6.36396) < 1e-6;
//   bool verifyD = abs(g_offsets[24].z - 0.00) < 1e-6;
//   if (!verifyA || !verifyB || !verifyC || !verifyD) 
//   {
//     o0 = float3(1,0,0);
//     o1 = 1;
//     return;
//   }
// #endif
// 
//   // setup
//   float blurFactorPrecomp = g_presort.SampleLevel(g_tile_sampler_s, v1.xy, 0).y;
// 
//   uint stepCount = 49u /* (uint)g_dof_param.z * (uint)g_dof_param.z */; // 49
//   uint stepCountHalf = stepCount / 2u; // 24
// 
//   float spreadScaleEffective = 3 * g_spread_scale.w;
//   float texcoordBlurFactorMultiplier = min(8, blurFactorPrecomp);
// 
//   float3 weightedColor = 0, areaWeightedColor = 0;
//   float colorWeight = 0, areaWeight = 0;
//   float3 weightedColorOut, areaWeightedColorOut; float colorWeightOut, areaWeightOut;
// 
//   // even pairs
//   [unroll] for (uint i = 0; i < stepCountHalf; i++)
//   {
//     float2 texcoordOffset0 = (g_offsets_static[i].xy / spreadScaleEffective) * texcoordBlurFactorMultiplier;
//     float2 texcoordOffset0Curr = texcoordOffset0 * g_texcoord_offset_for_upsample.zw + v1.xy;
//     float2 texcoordOffset0Scaled = texcoordOffset0 * g_spread_scale.z;
//     SampleBlur(texcoordOffset0Curr, texcoordOffset0Scaled, blurFactorPrecomp, weightedColorOut, colorWeightOut, areaWeightedColorOut, areaWeightOut);
//     weightedColor += weightedColorOut; colorWeight += colorWeightOut; areaWeightedColor += areaWeightedColorOut; areaWeight += areaWeightOut;
//       
//     float2 texcoordOffset1 = (g_offsets_static[i].zw / spreadScaleEffective) * texcoordBlurFactorMultiplier;
//     float2 texcoordOffset1Curr = texcoordOffset1 * g_texcoord_offset_for_upsample.zw + v1.xy;
//     float2 texcoordOffset1Scaled = texcoordOffset1 * g_spread_scale.z;
//     SampleBlur(texcoordOffset1Curr, texcoordOffset1Scaled, blurFactorPrecomp, weightedColorOut, colorWeightOut, areaWeightedColorOut, areaWeightOut);
//     weightedColor += weightedColorOut; colorWeight += colorWeightOut; areaWeightedColor += areaWeightedColorOut; areaWeight += areaWeightOut;
//   }
// 
//   // odd
//   if (stepCount /* % 2 */ & 1 != 0) 
//   {
//     float2 texcoordOffset0 = (g_offsets_static[stepCountHalf].xy / spreadScaleEffective) * texcoordBlurFactorMultiplier;
//     float2 texcoordOffset0Curr = texcoordOffset0 * g_texcoord_offset_for_upsample.zw + v1.xy;
//     float2 texcoordOffset0Scaled = texcoordOffset0 * g_spread_scale.z;
//     SampleBlur(texcoordOffset0Curr, texcoordOffset0Scaled, blurFactorPrecomp, weightedColorOut, colorWeightOut, areaWeightedColorOut, areaWeightOut);
//     weightedColor += weightedColorOut; colorWeight += colorWeightOut; areaWeightedColor += areaWeightedColorOut; areaWeight += areaWeightOut;
//   }
// 
//   // // debug skip blur
//   // weightedColor = g_color.SampleLevel(g_color_sampler_s, v1.xy, 0).xyz;
//   // colorWeight = 1;
//   // areaWeightedColor = 0;
//   // areaWeight = 0;
// 
//   // stepCountInv
//   float stepCountInv = rcp(stepCount);
//   stepCountInv += stepCountInv;
// 
//   // calculate surface area? CoC stuff
//   blurFactorPrecomp *= blurFactorPrecomp;
//   blurFactorPrecomp = max(blurFactorPrecomp, 0.5);
//   blurFactorPrecomp = saturate(stepCountInv * areaWeight * blurFactorPrecomp * 3.14159274);
// 
//   // normalize
//   colorWeight = max(colorWeight, 1e-4);
//   areaWeight = max(areaWeight, 1e-4);
//   weightedColor /= colorWeight;
//   areaWeightedColor /= areaWeight;
// 
//   // output
//   float3 colorWeightedDiff = areaWeightedColor - weightedColor;
//   o0.xyz = blurFactorPrecomp * colorWeightedDiff + weightedColor;
//   o0.xyz = pow(abs(o0.xyz), 1.0 / 2.2); // gamma encode (NEW, since non linear blending should be better)
//   
//   o1 = blurFactorPrecomp; // alpha blending
// 
//   return;
// }
// 
// //////////////////////////////////////////////////////////////////////////////////////////////
// 
// float4 UpsampleBicubic(float2 texcoord, float2 src_size, float2 inv_src_size)
// {
//   // transform the coordinate from [0,extent] to [-0.5, extent-0.5]
//   float2 coord_grid = texcoord * src_size - 0.5;
//   float2 index = floor(coord_grid);
//   float2 fraction = coord_grid - index;
//   float2 one_frac = 1.0 - fraction;
//   float2 one_frac2 = one_frac * one_frac;
//   float2 fraction2 = fraction * fraction;
//   float2 w0 = 1.0 / 6.0 * one_frac2 * one_frac;
//   float2 w1 = 2.0 / 3.0 - 0.5 * fraction2 * (2.0 - fraction);
//   float2 w2 = 2.0 / 3.0 - 0.5 * one_frac2 * (2.0 - one_frac);
//   float2 w3 = 1.0 / 6.0 * fraction2 * fraction;
//   float2 g0 = w0 + w1;
//   float2 g1 = w2 + w3;
//   
//   // h0 = w1/g0 - 1, move from [-0.5, extent-0.5] to [0, extent]
//   float2 h0 = (w1 / g0) - 0.5 + index;
//   float2 h1 = (w3 / g1) + 1.5 + index;
//   
//   // fetch the four linear interpolations
//   float3 tex00 = g_filtered_rgb.SampleLevel(g_filtered_rgb_sampler_s, float2(h0.x, h0.y) * inv_src_size, 0.0).rgb;
//   float3 tex10 = g_filtered_rgb.SampleLevel(g_filtered_rgb_sampler_s, float2(h1.x, h0.y) * inv_src_size, 0.0).rgb;
//   float3 tex01 = g_filtered_rgb.SampleLevel(g_filtered_rgb_sampler_s, float2(h0.x, h1.y) * inv_src_size, 0.0).rgb;
//   float3 tex11 = g_filtered_rgb.SampleLevel(g_filtered_rgb_sampler_s, float2(h1.x, h1.y) * inv_src_size, 0.0).rgb;
//   
//   // weigh along the y-direction
//   tex00 = lerp(tex01, tex00, g0.y);
//   tex10 = lerp(tex11, tex10, g0.y);
//   
//   // weigh along the x-direction
//   return float4(lerp(tex10, tex00, g0.x), 1.0);
// }
// 
// void resolve(
//   float4 v0 : SV_POSITION0,
//   float4 v1 : TEXCOORD0,
//   out float4 o0 : SV_Target0)
// {
//   float4 r0,r1,r2,r3,r4,r5,r6,r7,r8,r9,r10,r11;
//   uint4 bitmask, uiDest;
//   float4 fDest;
// 
//   // original color center
//   r0.xyzw = g_full_res_color.SampleLevel(g_full_res_color_sampler_s, v1.xy, 0).xyzw;
//   // r0.xyz = pow(abs(r0.xyz), 2.2); // gamma decode (linearize)
// 
//   // upsample
//   #if 0
//     r1.xyz = UpsampleBicubic(v1.xy, LumaSettings.RenderSize, LumaSettings.RenderInvSize).xyz; // this barely does anything
//   #else
//     // original specific 9-tap
//     r2.xyw = -g_texcoord_offset_for_upsample.xyy;
//     r2.xy = v1.xy + r2.xy;
//     r3.xyz = g_filtered_rgb.SampleLevel(g_filtered_rgb_sampler_s, r2.xy, 0).xyz;
//     r2.z = 0;
//     r2.xy = v1.xy + r2.zw;
//     r2.xyz = g_filtered_rgb.SampleLevel(g_filtered_rgb_sampler_s, r2.xy, 0).xyz;
//     r4.xyzw = g_texcoord_offset_for_upsample.xyxy * float4(1,-1,-1,1) + v1.xyxy;
//     r5.xyz = g_filtered_rgb.SampleLevel(g_filtered_rgb_sampler_s, r4.xy, 0).xyz;
//     r6.x = -g_texcoord_offset_for_upsample.x;
//     r6.yw = float2(0,0);
//     r4.xy = v1.xy + r6.xy;
//     r7.xyz = g_filtered_rgb.SampleLevel(g_filtered_rgb_sampler_s, r4.xy, 0).xyz;
//     r8.xyz = g_filtered_rgb.SampleLevel(g_filtered_rgb_sampler_s, v1.xy, 0).xyz;
//     r6.z = g_texcoord_offset_for_upsample.x;
//     r4.xy = v1.xy + r6.zw;
//     r6.xyz = g_filtered_rgb.SampleLevel(g_filtered_rgb_sampler_s, r4.xy, 0).xyz;
//     r4.xyz = g_filtered_rgb.SampleLevel(g_filtered_rgb_sampler_s, r4.zw, 0).xyz;
//     r9.x = 0;
//     r9.y = g_texcoord_offset_for_upsample.y;
//     r9.xy = v1.xy + r9.xy;
//     r9.xyz = g_filtered_rgb.SampleLevel(g_filtered_rgb_sampler_s, r9.xy, 0).xyz;
//     r10.xy = g_texcoord_offset_for_upsample.xy + v1.xy;
//     r10.xyz = g_filtered_rgb.SampleLevel(g_filtered_rgb_sampler_s, r10.xy, 0).xyz;
//     r11.xyz = min(r5.xyz, r2.xyz);
//     r2.xyz = max(r5.xyz, r2.xyz);
//     r5.xyz = max(r11.xyz, r3.xyz);
//     r3.xyz = min(r11.xyz, r3.xyz);
//     r11.xyz = min(r5.xyz, r2.xyz);
//     r2.xyz = max(r5.xyz, r2.xyz);
//     r5.xyz = min(r8.xyz, r6.xyz);
//     r6.xyz = max(r8.xyz, r6.xyz);
//     r8.xyz = max(r7.xyz, r5.xyz);
//     r5.xyz = min(r7.xyz, r5.xyz);
//     r7.xyz = min(r8.xyz, r6.xyz);
//     r6.xyz = max(r8.xyz, r6.xyz);
//     r8.xyz = min(r10.xyz, r9.xyz);
//     r9.xyz = max(r10.xyz, r9.xyz);
//     r10.xyz = max(r8.xyz, r4.xyz);
//     r4.xyz = min(r8.xyz, r4.xyz);
//     r8.xyz = min(r10.xyz, r9.xyz);
//     r9.xyz = max(r10.xyz, r9.xyz);
//     r3.xyz = max(r5.xyz, r3.xyz);
//     r3.xyz = max(r3.xyz, r4.xyz);
//     r4.xyz = min(r9.xyz, r6.xyz);
//     r2.xyz = min(r4.xyz, r2.xyz);
//     r4.xyz = min(r8.xyz, r7.xyz);
//     r5.xyz = max(r8.xyz, r7.xyz);
//     r4.xyz = max(r11.xyz, r4.xyz);
//     r4.xyz = min(r5.xyz, r4.xyz);
//     r5.xyz = min(r4.xyz, r2.xyz);
//     r2.xyz = max(r4.xyz, r2.xyz);
//     r3.xyz = max(r5.xyz, r3.xyz);
//     r1.xyz = min(r3.xyz, r2.xyz);
//   #endif
//   // r1.xyz = g_filtered_rgb.SampleLevel(g_filtered_rgb_sampler_s, v1.xy, 0).xyz; // debug no upsample
//   // o0.xyz = abs(r1.xyz); return; // debug see raw dof
// 
//   // alpha for blending
//   r1.w = g_filtered_a.SampleLevel(g_filtered_a_sampler_s, v1.xy, 0).x;
// 
//   // linear center depth
//   r2.x = g_full_res_depth.SampleLevel(g_full_res_depth_sampler_s, v1.xy, 0).x;
//   r2.x = rcp(r2.x * g_depth_params.x + g_depth_params.y);
// 
//   // blur factor center
//   r2.x = CalculateBlurFactor(r2.x, g_depth_params2);
// 
//   // blend from tile blur weights diff // TODO: wth is happening?
//   r2.y = g_presort_5.SampleLevel(g_tile_sampler_s, v1.zw, 0).y; // REQUIRES: min-biased blurFactor
//   r2.xy = r2.xy * r2.xy;
//   r2.xy = max(float2(0.5,0.5), r2.xy);
//   r2.xy = float2(3.14159274,3.14159274) * r2.xy;
//   r2.x = 1 / r2.x;
//   r2.y = 1 / r2.y;
// 
//   r2.y = r2.y + -r2.x; // diff
//   r2.x = r2.x + r2.x;
//   r1.w = r1.w * r2.y + r2.x;
//   r1.w = 1 + -r1.w;
//   r1.w = -r1.w * r1.w + 1;
//   r1.w = saturate(r1.w * 4 + -0.200000003);
//   r0.xyz = -r1.xyz + r0.xyz;
//   r0.xyz = r1.www * r0.xyz + r1.xyz;
// 
//   // o0.xyz = pow(abs(r0.xyz), 1/2.2); // gamma encode
//   o0.xyz = abs(r0.xyz); // blend was in gamma
// 
//   o0.w = r0.w; // full res alpha channel
//   return;
// }