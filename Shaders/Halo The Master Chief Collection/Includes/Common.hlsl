#ifndef __COMMON_HLSLI__
#define __COMMON_HLSLI__

#define USE_GTAO 1

#include "GameCBuffers.hlsl"
#include "../../Includes/Common.hlsl"
#include "Settings.hlsl"

#define GS LumaSettings.GameSettings

//  enum SubGame : uint8_t
//  {
//     Unknown,
//     Halo1Classic,
//     Halo1Anniversary,
//     Halo2Classic,
//     Halo2Anniversary,
//     Halo2AnniversaryMP,
//     Halo3,
//     Halo3ODST,
//     HaloReach,
//     Halo4,
//  };

bool IsGame_Unknown() {return GS.SubGame == 1;}
bool IsGame_Halo1Classic() {return GS.SubGame == 1;}
bool IsGame_Halo1Anniversary() {return GS.SubGame == 2;}
bool IsGame_Halo2Classic() {return GS.SubGame == 3;}
bool IsGame_Halo2Anniversary() {return GS.SubGame == 4;}
bool IsGame_Halo2AnniversaryMP() {return GS.SubGame == 5;}
bool IsGame_Halo3() { return GS.SubGame == 6;}
bool IsGame_Halo3ODST() {return GS.SubGame == 7;}
bool IsGame_HaloReach() {return GS.SubGame == 8;}
bool IsGame_Halo4() {return GS.SubGame == 9;}

float3 sRGB_Encode(float3 x) {return linear_to_sRGB_gamma(x, GCT_NONE);}
float  sRGB_Encode(float  x) {return linear_to_sRGB_gamma1(x, GCT_NONE);}
float3 sRGB_Decode(float3 x) {return gamma_sRGB_to_linear(x, GCT_NONE);}
float  sRGB_Decode(float  x) {return gamma_sRGB_to_linear1(x, GCT_NONE);}

#define HDR_ENABLED LumaSettings.DisplayMode == 1
#define HDR_PEAK PeakWhiteNits / GamePaperWhiteNits
#define HDR_INTSCALING GamePaperWhiteNits / UIPaperWhiteNits
#define HDR_SHOULDERSTART GS.TonemapperRolloffStart / GamePaperWhiteNits
#define HDR_MAXEXPECTED GS.TonemapperMaxExpected / GamePaperWhiteNits
#define HDR_STOPS log2(HDR_PEAK)

/////////////////////////////////////////////////////////////////////////////////////////
float Neutwo(float x) {
  float numerator = x;
  float denominator_squared = mad(x, x, 1.0);
  return numerator * rsqrt(denominator_squared);
}

float Neutwo(float x, float peak) {
  float p = peak;

  float numerator = p * x;
  float denominator_squared = mad(x, x, p * p);
  return numerator * rsqrt(denominator_squared);
}
float3 Neutwo(float3 x, float peak) {
  float p = peak;

  float3 numerator = p * x;
  float3 denominator_squared = mad(x, x, p * p);
  return numerator * rsqrt(denominator_squared);
}

float3 Neupow(float3 x, float peak, float power) {
  float3 p_over_x_pow_a = exp2(power * (log2(peak) - log2(x)));
  return peak * rcp(exp2(log2(1.0f + p_over_x_pow_a) * rcp(power)));
}
float Neupow(float x, float peak, float power) {
  float p_over_x_pow_a = exp2(power * (log2(peak) - log2(x)));
  return peak * rcp(exp2(log2(1.0f + p_over_x_pow_a) * rcp(power)));
}
float3 NeupowHQ(float3 x, float peak, float power) {
  return (x * peak) / pow(pow(x, power) + pow(peak, power), rcp(power));
}
float NeupowHQ(float x, float peak, float power) {
  return (x * peak) / pow(pow(x, power) + pow(peak, power), rcp(power));
}

float Neutwo(float x, float peak, float clip) {
  float p = peak;
  float c = clip;
  float cc = c * c;
  float pp = p * p;
  float xx = x * x;

  float numerator = c * p * x;
  float denominator_squared = mad(xx, (cc - pp), cc * pp);

  return numerator * rsqrt(denominator_squared);
}
float3 Neutwo(float3 x, float peak, float clip) {
  float p = peak;
  float c = clip;
  float cc = c * c;
  float pp = p * p;
  float3 xx = x * x;

  float3 numerator = c * p * x;
  float3 denominator_squared = mad(xx, (cc - pp), cc * pp);

  return numerator * rsqrt(denominator_squared);
}

float Neupow(float x, float peak, float clip, float power) {
  // return (clip * peak * x) / pow(pow(x, power) * (pow(clip, power) - pow(peak, power)) + (pow(clip, power) * pow(peak, power)), rcp(power));

  float log2_x = log2(x);
  float x_pow_a = exp2(power * log2_x);
  float k = exp2(-power * log2(peak)) - exp2(-power * log2(clip));
  return exp2(log2_x - log2(k * x_pow_a + 1.0f) * rcp(power));
}
float3 Neupow(float3 x, float peak, float clip, float power) {
  // return (clip * peak * x) / pow(pow(x, power) * (pow(clip, power) - pow(peak, power)) + (pow(clip, power) * pow(peak, power)), rcp(power));

  float3 log2_x = log2(x);
  float3 x_pow_a = exp2(power * log2_x);
  float3 k = exp2(-power * log2(peak)) - exp2(-power * log2(clip));
  return exp2(log2_x - log2(k * x_pow_a + 1.0f) * rcp(power));
}

float ReinhardClip(float x, float peak, float clip) { //when power = 1
  return (clip * peak * x) / (x * (clip - peak) + (clip * peak));
}

float3 ReinhardClip(float3 x, float peak, float clip) { //when power = 1
  return (clip * peak * x) / (x * (clip - peak) + (clip * peak));
}

/////////////////////////////////////////////////////////////////////////////////////////

//Extension: slope_at_piecewise * (x - thres_at_piecewise) + output_at_piecewise
float3 LinearPiecewiseExtension(float3 sdr, float3 hdr, float thres, float slope, float output)
{
  float3 lower = sdr;
  float3 upper = slope * (hdr - thres) + output;
  return hdr < thres ? lower : upper;
}

/////////////////////////////////////////////////////////////////////////////////////////

// #include "../Includes/JzAzBz.hlsl"
#include "./ictcp_portable.hlsl"
float3 UCS_Encode(float3 x) {
  // return JzAzBz::rgbToJzazbz(x, CS_BT709);
  return renodx::color::ictcp::Encode(x, CS_BT709);
}
float3 UCS_Decode(float3 x) {
  // return JzAzBz::jzazbzToRgb(x, CS_BT709);
  return renodx::color::ictcp::Decode(x, CS_BT709);
}
float3 RestoreHueAndChrominanceUcsInternal(float3 targetUcs, float3 sourceUcs, float currentChrominance, float hueStrength, float chrominanceStrength, float minChromaRatio = 0.f)
{
  if (targetUcs.x == 0) return targetUcs;

  if (hueStrength != 0.0)
  {
    const float chrominancePre = currentChrominance;
    targetUcs.yz = lerp(targetUcs.yz, sourceUcs.yz, hueStrength);
    const float chrominancePost = length(targetUcs.yz);
    float chrominanceRatio = safeDivision(chrominancePre, chrominancePost, 1);
    targetUcs.yz *= chrominanceRatio;
  }

  if (chrominanceStrength != 0.0)
  {
    const float sourceChrominance = length(sourceUcs.yz);
    float targetChrominanceRatio = safeDivision(sourceChrominance, currentChrominance, 1);
    targetChrominanceRatio = clamp(targetChrominanceRatio, minChromaRatio, 99999999);
    targetUcs.yz *= lerp(1.0, targetChrominanceRatio, chrominanceStrength);
  }

  return targetUcs;
}

float3 RestoreHueAndChrominanceUcs(float3 targetUcs, float3 sourceUcs, float hueStrength, float chrominanceStrength, float minChromaRatio = 0.f)
{
  return RestoreHueAndChrominanceUcsInternal(targetUcs, sourceUcs, length(targetUcs.yz), hueStrength, chrominanceStrength, minChromaRatio);
}
/////////////////////////////////////////////////////////////////////////////////////////

float GammaCorrectionPeak(float x) {
  #if GAMMA_CORRECTION_TYPE > 0
    x = gamma_sRGB_to_linear1(x, GCT_NONE);
    x = linear_to_gamma1(x, GCT_NONE, DefaultGamma);
  #endif
  return x;
}

float3 GammaCorrectionLinearDown(float3 x) {
  #if GAMMA_CORRECTION_TYPE > 0
    x = linear_to_sRGB_gamma(x, GCT_NONE);
    x = gamma_to_linear(x, GCT_NONE, DefaultGamma);
  #endif
  return x;
}
float3 GammaCorrectionLinearUp(float3 x) {
  #if GAMMA_CORRECTION_TYPE > 0
    x = gamma_to_linear(x, GCT_NONE, DefaultGamma);
    x = linear_to_sRGB_gamma(x, GCT_NONE);
  #endif
  return x;
}

float3 RenderIntermediatePass_Decode(float3 x) {
  #if GAMMA_CORRECTION_TYPE == 0
    x = gamma_sRGB_to_linear(x, GCT_NONE);
  #else
    x = gamma_to_linear(x, GCT_NONE, DefaultGamma);
  #endif
  return x;
}
float3 RenderIntermediatePass_Encode(float3 x) {
  #if GAMMA_CORRECTION_TYPE == 0
    x = linear_to_sRGB_gamma(x, GCT_NONE);
  #else
    x = linear_to_gamma(x, GCT_NONE, DefaultGamma);
  #endif
  return x;
}

float3 RenderIntermediatePass(float3 x, float scaling = 1) {
  x = max(x, 0);
  if (!HDR_ENABLED) return x;
  x = RenderIntermediatePass_Decode(x);
  x *= HDR_INTSCALING * scaling;
  x = RenderIntermediatePass_Encode(x);
  return x;
}

float3 RenderIntermediatePassFromLinear(float3 x, float scaling = 1) {
  x = max(x, 0);
  if (!HDR_ENABLED) return x;
  x = GammaCorrectionLinearDown(x);
  x *= HDR_INTSCALING * scaling;
  x = RenderIntermediatePass_Encode(x);
  return x;
}

float3 UIScaling(float3 x) {
  x = sRGB_Decode(x);
  x /= HDR_INTSCALING;
  x = sRGB_Encode(x);
  return x;
}
// float4 UIScaling(float4 x) {
//   x = sRGB_Decode(x);
//   x /= HDR_INTSCALING;
//   x = sRGB_Encode(x);
//   return x;
// }

#endif // __COMMON_HLSLI__