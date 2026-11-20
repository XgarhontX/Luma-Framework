// Depth of Field, disc bokeh
//
// main reference, for disc: https://github.com/keijiro/KinoBokeh
// straight forward full res DoF hype: https://github.com/ninjamica/Painted-DOF/blob/main/DOF_Paint.fx
// for hexagonal (not implemented): https://github.com/zigguratvertigo/HexBokehBlur/blob/master/HexagonalBokehBlur.rfx

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

#define COC_MAX 0.65 // vanilla faithful fudge (max kernel can handle @ 4k is about 0.65)
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

  bool isNear = linearDepth < params.x;

  if (isParamW) x *= params.w; // final multiplier, gets clamped later

  if (isCustom) // vanilla faithful fudge
  {
    x = max(x, 0);

    #if CUSTOM_DOF_CURVEPROFILE == 0
      x = pow(x * 0.16, 1.2);
    #else
      if (isNear) x *= 0.2; // vanilla is like this too, where thres is harder to reach
      else x *= 0.3;
      x *= x;
    #endif
    // x = pow(x * DVS1, DVS2);

    x = min(x, COC_MAX);
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

  #if BLUR_IN_LINEAR && CUSTOM_DOF_LUMAWEIGHTS
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
  #if BLUR_IN_LINEAR
    o0.xyz = pow(o0.xyz, 1 / 2.2);
  #endif
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
  acc += t_halfprev.SampleLevel(s_linear, uv         , 0) * 4;
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
  float2 pixSizeHalf = LumaSettings.RenderInvSize * 2;

  o0 = Sample9Tent(v1.xy, pixSizeHalf); // expand blur, so reconstruct is easier
}

void BokehSim2(
  float4 v0 : SV_POSITION0, // pix pos
  float4 v1 : TEXCOORD0, // center: xy
  out float4 o0 : SV_Target0
)
{
  float2 pixSizeQuarter = LumaSettings.RenderInvSize * 4;

  o0 = Sample9Tent(v1.xy, pixSizeQuarter); // expand blur, so reconstruct is easier
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
  cs.xyz = abs(cs.xyz);
  cs.w = saturate(cs.w);
  // #if BLUR_IN_LINEAR
  //   cs.xyz = pow(cs.xyz, 2.2);
  // #endif
  o0 = cs;

  float depth = LinearizeDepth(t_depth.Load(int3(v0.xy, 0)));

  // upsample
  float4 cb = t_halfprev.SampleLevel(s_linear, v1.xy, 0);
  // float4 cb = Sample9Tent(v1.xy, pixSizeHalf); // barely a diff

  // reconstruction cheese (AI helped)
  float A = saturate(1-cb.a);
  float3 B = cb.rgb / max(A, 1e-5);
  // float A = cb.a;
  // float3 B = cb.rgb;

  // mimic Prefilter coc as best as possible (AI helped)
  float coc = CalculateBlurFactor(depth, false, true, true, true) * COC_FUDGE;
  float radiusPixels = abs(coc) * COC_MAX * texSizeMain.y;

  // mask feather (AI helped)
  const float radiusStart = 0.0; // fudge
  const float radiusEnd = 16.0 * texSizeMain.y / 2160.0; // fudge, based on 4k
  const float coverageConfidence = 0.5; // fudge
  float mask = smoothstep(radiusStart, radiusEnd, radiusPixels);
  mask *= smoothstep(0, coverageConfidence, A);
  float3 rgb = lerp(cs.rgb, B, mask);
  
  // out
  // #if BLUR_IN_LINEAR
  //   rgb = pow(rgb, 1/2.2);
  // #endif
  o0 = half4(rgb, cs.a);
}