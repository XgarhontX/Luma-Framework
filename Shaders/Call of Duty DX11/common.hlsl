#include "Includes/Common.hlsl"
#include "../Includes/Reinhard.hlsl"
#include "Includes/ictcp_portable.hlsl"

///////////////////////////////////////////////////////////////////////////////////////////////////
float3 ClampByMaxChannel(float3 x, float p) {
  float maxChannel = max(x.x, max(x.y, x.z));
  if (maxChannel > p) x *= p / maxChannel;
  return x;
}
///////////////////////////////////////////////////////////////////////////////////////////////////
float3 UCS_ToUCS(float3 color) {
  return renodx::color::ictcp::ToUCS(color, 0);
}

float3 UCS_FromUCS(float3 color) {
  return renodx::color::ictcp::FromUCS(color, 0);
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
    targetChrominanceRatio = clamp(targetChrominanceRatio, minChromaRatio, FLT_MAX);
    targetUcs.yz *= lerp(1.0, targetChrominanceRatio, chrominanceStrength);
  }

  return targetUcs;
}

float3 RestoreHueAndChrominanceUcs(float3 targetUcs, float3 sourceUcs, float hueStrength, float chrominanceStrength, float minChromaRatio = 0.f)
{
  return RestoreHueAndChrominanceUcsInternal(targetUcs, sourceUcs, length(targetUcs.yz), hueStrength, chrominanceStrength, minChromaRatio);
}
///////////////////////////////////////////////////////////////////////////////////////////////////
//https://github.com/clshortfuse/renodx/blob/main/src/shaders/tonemap/neutwo.hlsl
float Neutwo(float x) {
  // also written as x * rhypot(x, 1.0)
  float numerator = x;
  float denominator_squared = mad(x, x, 1.0);
  return numerator * rsqrt(denominator_squared);
}

// f_{p}\left(x\right)=\frac{px}{\sqrt{xx+pp}}
float Neutwo(float x, float peak) {
  // also written as x * rhypot(x, peak)
  float p = peak;

  float numerator = p * x;
  float denominator_squared = mad(x, x, p * p);
  return numerator * rsqrt(denominator_squared);
}
float3 Neutwo(float3 x, float peak) {
  // also written as x * rhypot(x, peak)
  float p = peak;

  float3 numerator = p * x;
  float3 denominator_squared = mad(x, x, p * p);
  return numerator * rsqrt(denominator_squared);
}

// f_{c}\left(x\right)=\frac{cpx}{\sqrt{xx\cdot\left(cc-pp\right)+\left(cc\cdot pp\right)}}
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

// f_{g}\left(x\right)=\frac{pgx\left(cc-gg\right)}{\sqrt{\left(cc-gg\right)\cdot gg\cdot\left(xx\cdot\left(cc-pp\right)+cc\cdot\left(pp-gg\right)\right)}}
float Neutwo(float x, float peak, float clip, float gray) {
  float p = peak;
  float g = gray;
  float c = clip;

  float cc = c * c;
  float pp = p * p;
  float gg = g * g;
  float xx = x * x;
  float cc_minus_gg = cc - gg;

  float numerator = p * g * x * cc_minus_gg;
  float denominator_squared = cc_minus_gg * gg * (mad(xx, (cc - pp), cc * (pp - gg)));
  return numerator * rsqrt(denominator_squared);
}
float3 Neutwo(float3 x, float peak, float clip, float gray) {
  float p = peak;
  float g = gray;
  float c = clip;

  float cc = c * c;
  float pp = p * p;
  float gg = g * g;
  float3 xx = x * x;
  float cc_minus_gg = cc - gg;

  float3 numerator = p * g * x * cc_minus_gg;
  float3 denominator_squared = cc_minus_gg * gg * (mad(xx, (cc - pp), cc * (pp - gg)));
  return numerator * rsqrt(denominator_squared);
}

// f_{o}\left(x\right)=\frac{pox\left(cc-gg\right)}{\sqrt{\left(cc-gg\right)\cdot\left(xx\cdot\left(ccoo-ppgg\right)+ccgg\cdot\left(pp-oo\right)\right)}}
float Neutwo(float x, float peak, float clip, float gray_in, float gray_out) {
  float p = peak;
  float g = gray_in;
  float o = gray_out;

  float cc = clip * clip;
  float pp = peak * peak;
  float gg = g * g;
  float oo = o * o;
  float xx = x * x;

  float cc_minus_gg = cc - gg;

  float numerator = p * o * x * cc_minus_gg;

  float ccoo = cc * oo;
  float ppgg = pp * gg;
  float ccgg = cc * gg;

  float denominator_squared = cc_minus_gg * mad(xx, (ccoo - ppgg), ccgg * (pp - oo));

  return numerator * rsqrt(denominator_squared);
}
float3 Neutwo(float3 x, float peak, float clip, float gray_in, float gray_out) {
  float p = peak;
  float g = gray_in;
  float o = gray_out;

  float cc = clip * clip;
  float pp = peak * peak;
  float gg = g * g;
  float oo = o * o;
  float3 xx = x * x;

  float cc_minus_gg = cc - gg;

  float3 numerator = p * o * x * cc_minus_gg;

  float ccoo = cc * oo;
  float ppgg = pp * gg;
  float ccgg = cc * gg;

  float3 denominator_squared = cc_minus_gg * mad(xx, (ccoo - ppgg), ccgg * (pp - oo));

  return numerator * rsqrt(denominator_squared);
}

// f_{i}\left(x\right)=\frac{x}{\sqrt{-xx+1}}
float NeutwoI(float x) {
  float numerator = x;
  float denominator_squared = mad(-x, x, 1.0);
  return numerator * rsqrt(denominator_squared);
}

// f_{pi}\left(x\right)=\frac{px}{\sqrt{-xx+pp}}
float NeutwoI(float x, float peak) {
  float p = peak;

  float numerator = p * x;
  float denominator_squared = mad(-x, x, p * p);
  return numerator * rsqrt(denominator_squared);
}

// f_{ci}\left(x\right)=\frac{cpx}{\sqrt{-xx\cdot\left(cc-pp\right)+\left(cc\cdot pp\right)}}
float NeutwoI(float x, float peak, float clip) {
  float p = peak;
  float c = clip;
  float cc = c * c;
  float pp = p * p;
  float xx = x * x;

  float numerator = c * p * x;
  float denominator_squared = mad(-xx, (cc - pp), cc * pp);

  return numerator * rsqrt(denominator_squared);
}
float3 NeutwoI(float3 x, float peak, float clip) {
  float p = peak;
  float c = clip;
  float cc = c * c;
  float pp = p * p;
  float3 xx = x * x;

  float3 numerator = c * p * x;
  float3 denominator_squared = mad(-xx, (cc - pp), cc * pp);

  return numerator * rsqrt(denominator_squared);
}

// f_{gi}\left(x\right)=\frac{pgx\left(cc-gg\right)}{\sqrt{\left(cc-gg\right)\cdot gg\cdot\left(-xx\cdot\left(cc-pp\right)+cc\cdot\left(pp-gg\right)\right)}}
float NeutwoI(float x, float peak, float clip, float gray) {
  float p = peak;
  float g = gray;
  float c = clip;

  float cc = c * c;
  float pp = p * p;
  float gg = g * g;
  float xx = x * x;
  float cc_minus_gg = cc - gg;

  float numerator = p * g * x * cc_minus_gg;
  float denominator_squared = cc_minus_gg * gg * (mad(-xx, (cc - pp), cc * (pp - gg)));
  return numerator * rsqrt(denominator_squared);
}
///////////////////////////////////////////////////////////////////////////////////////////////////
// Uchimura 2018, "Practical HDR and Wide Color Techniques in Gran Turismo SPORT"
// https://www.desmos.com/calculator/gslcdxvipg
// http://cdn2.gran-turismo.com/data/www/pdi_publications/PracticalHDRandWCGinGTS.pdf
#define GTTONEMAP_GENERATOR(T)                \
  T GTTonemap(T x,                            \
              float P = 1.f,                  \
              float a = 1.f,                  \
              float m = 0.22f,                \
              float l = 0.4f,                 \
              float c = 1.33f,                \
              float b = 0.f) {                \
    float l0 = ((P - m) * l) / a;             \
    float L0 = m - (m / a);                   \
    float L1 = m + (1.0f - m) / a;            \
                                              \
    T S0 = m + l0;                            \
    T S1 = m + a * l0;                        \
    T C2 = (a * P) / (P - S1);                \
    T CP = -C2 / P;                           \
                                              \
    T w0 = 1.0f - smoothstep(0.0f, m, x);     \
    T w2 = step(m + l0, x);                   \
    T w1 = 1.0f - w0 - w2;                    \
                                              \
    T T_ = m * pow(x / m, c) + b;             \
    T S_ = P - (P - S1) * exp(CP * (x - S0)); \
    T L_ = m + a * (x - m);                   \
                                              \
    return T_ * w0 + L_ * w1 + S_ * w2;       \
  }
GTTONEMAP_GENERATOR(float)
GTTONEMAP_GENERATOR(float3)
#undef GTTONEMAP_GENERATOR
float3 GTTonemapNoToe(
  float3 x,            
  float P = 1.f,  
  float m = 0.22f) {                                             
  float3 C2 = P / (P - m);               
  float3 CP = -C2 / P;                          
                                            
  bool3 w2 = x > m;                
                                            
  float3 S_ = P - (P - m) * exp(CP * (x - m));
  float3 L_ = m + (x - m);
  
  return !w2 ? L_ : S_;
}
float3 GTTonemapShoulderOnly(float3 x, float P = 1.f) {
  float3 S_ = P - P * exp(-x);
  return S_;
}
///////////////////////////////////////////////////////////////////////////////////////////////////
/// Piecewise linear + exponential compression to a target value starting from a specified number.
/// https://www.ea.com/frostbite/news/high-dynamic-range-color-grading-and-display-in-frostbite
#define EXPONENTIALROLLOFF_GENERATOR(T)                                                 \
  T ExponentialRollOff(T input, float rolloff_start = 0.20f, float output_max = 1.0f) { \
    T rolloff_size = output_max - rolloff_start;                                        \
    T overage = -max((T)0, input - rolloff_start);                                      \
    T rolloff_value = (T)1.0f - exp(overage / rolloff_size);                            \
    T new_overage = mad(rolloff_size, rolloff_value, overage);                          \
    return input + new_overage;                                                         \
  }

/// Piecewise linear + exponential compression to a target value starting from a specified number.
/// https://www.ea.com/frostbite/news/high-dynamic-range-color-grading-and-display-in-frostbite
#define EXPONENTIALROLLOFF_CLIP_GENERATOR(T)                                         \
  T ExponentialRollOff(T input, float rolloff_start, float output_max, float clip) { \
    T rolloff_size = output_max - rolloff_start;                                     \
    T overage = -max((T)0, input - rolloff_start);                                   \
    T clip_size = rolloff_start - clip;                                              \
    T rolloff_value = (T)1.0f - exp(overage / rolloff_size);                         \
    T clip_value = (T)1.0f - exp(clip_size / rolloff_size);                          \
    T new_overage = mad(rolloff_size, rolloff_value / clip_value, overage);          \
    return input + new_overage;                                                      \
  }

EXPONENTIALROLLOFF_GENERATOR(float)
EXPONENTIALROLLOFF_GENERATOR(float3)
EXPONENTIALROLLOFF_CLIP_GENERATOR(float)
EXPONENTIALROLLOFF_CLIP_GENERATOR(float3)
#undef EXPONENTIALROLLOFF_GENERATOR
#undef EXPONENTIALROLLOFF_CLIP_GENERATOR
///////////////////////////////////////////////////////////////////////////////////////////////////
//https://github.com/clshortfuse/renodx/blob/main/src/shaders/tonemap/reinhard.hlsl
namespace Reinhard {
  float ReinhardPiecewiseExtended(float x, float white_max, float x_max = 1.f, float shoulder = 0.18f)
  {
     const float x_min = 0.f;
     float exposure = Reinhard::ComputeReinhardExtendableScale(white_max, x_max, x_min, shoulder, shoulder);
     float extended = Reinhard::ReinhardExtended(x * exposure, white_max * exposure, x_max);
     extended = min(extended, x_max);

     return lerp(x, extended, step(shoulder, x));
  }
  float3 ReinhardPiecewiseExtended(float3 x, float white_max, float x_max = 1.f, float shoulder = 0.18f)
  {
     const float x_min = 0.f;
     float exposure = Reinhard::ComputeReinhardExtendableScale(white_max, x_max, x_min, shoulder, shoulder);
     float3 extended = Reinhard::ReinhardExtended(x * exposure, white_max * exposure, x_max);
     extended = min(extended, x_max);

     return lerp(x, extended, step(shoulder, x));
  }

  float ComputeReinhardSmoothClampScale(float3 untonemapped, float rolloff_start = 0.5f, float output_max = 1.f, float white_clip = 100.f)
  {
     float peak = max3(untonemapped.r, untonemapped.g, untonemapped.b);
     float mapped_peak = ReinhardPiecewiseExtended(peak, white_clip, output_max, rolloff_start);
     float scale = safeDivision(mapped_peak, peak, 0);

     return scale;
  }

  //https://github.com/patriciogonzalezvivo/lygia/blob/main/color/tonemap/reinhardJodie.hlsl
  //https://web.archive.org/web/20210205114323/http://www.cmap.polytechnique.fr/~peyre/cours/x2005signal/hdr_photographic.pdf
  float3 Jodie(float3 x, float peak = 1.f, float perchannelInfluence = 1.f, uint cs = CS_BT709) {
     float3 perScaled = Reinhard::ReinhardSimple(x, peak);

     float y = GetLuminance(x, cs);
     float3 yScaled = x / (y + 1.0f);

     x = lerp(yScaled, perScaled, y * perchannelInfluence);
     x = min(x, peak);

     return x;
  }

  namespace inverse {
    float3 ReinhardScalable(float3 color, float channel_max = 1.f, float channel_min = 0.f, float gray_in = 0.18f, float gray_out = 0.18f) {
      float exposure = (channel_max * (channel_min * gray_out + channel_min - gray_out))
                       / (gray_in * (gray_out - channel_max));

      float3 numerator = -channel_max * (channel_min * color + channel_min - color);
      float3 denominator = (exposure * (channel_max - color));
      return safeDivision(numerator, denominator, FLT16_MAX);
    }

    float ReinhardScalable(float color, float channel_max = 1.f, float channel_min = 0.f, float gray_in = 0.18f, float gray_out = 0.18f) {
      float exposure = (channel_max * (channel_min * gray_out + channel_min - gray_out))
                       / (gray_in * (gray_out - channel_max));

      float numerator = -channel_max * (channel_min * color + channel_min - color);
      float denominator = (exposure * (channel_max - color));
      return safeDivision(numerator, denominator, FLT16_MAX);
    }

    float3 Reinhard(float3 color) {
      return safeDivision(color, (1.f - color), FLT16_MAX);
    }

    float Reinhard(float color) {
      return safeDivision(color, (1.f - color), FLT16_MAX);
    }
  }
}
///////////////////////////////////////////////////////////////////////////////////////////////////
float3 CorrectPerChannelTonemapHiglightsDesaturation1(float3 color, float peakBrightness, float desaturationExponent = 2.0, float highlightsOnly = 2)
{
  float3 colorUcs = UCS_ToUCS(color);
  float sourceChrominance = length(colorUcs.yz);

  float maxBrightness = max3(color); 
  float midBrightness = GetMidValue(color);
	float minBrightness = min3(color);
	float brightnessRatio = saturate(maxBrightness / peakBrightness);

  brightnessRatio = lerp(brightnessRatio, sqrt(brightnessRatio), sqrt(saturate(InverseLerp(minBrightness, maxBrightness, midBrightness))));
  brightnessRatio = pow(brightnessRatio, highlightsOnly); // skewed towards highlights only

  float chrominancePow = lerp(1.0, 1.0 / desaturationExponent, brightnessRatio);
  
  float targetChrominance = sourceChrominance > 1.0 ? pow(sourceChrominance, chrominancePow) : (1.0 - pow(1.0 - sourceChrominance, chrominancePow));
  float chrominanceRatio = safeDivision(targetChrominance, sourceChrominance, 1);

  // return RestoreLuminance(SetChrominance(color, chrominanceRatio), color, true, colorSpace);
  colorUcs.yz *= chrominanceRatio;
  color = UCS_FromUCS(colorUcs);
  color = max(0, color);
  return color;
}
///////////////////////////////////////////////////////////////////////////////////////////////////
//https://www.desmos.com/calculator/kdea4muqwb

float3 MobiusRolloff(float3 x, float4 c) {
  return (x * c.x + c.z) / (x * c.y + c.w);
}
float MobiusRolloff(float x, float4 c) {
  return (x * c.x + c.z) / (x * c.y + c.w);
}

float MobiusRolloffDerivative(float x, float4 c) {
    float numer = c.y * c.z - c.w * c.x;
    float denom = c.y * x + c.w;
    float slope = -numer / (denom * denom);
    return slope;
}
///////////////////////////////////////////////////////////////////////////////////////////////////
// Emulate luminance loss/clipping from LDR per-channel tonemap on high single channel colors.
//
// Takes in raw/no-blowout linear color, do per-channel tonemap, then do inverse luminance tonemap.
// That gives a luminance ratio to reduce HDR luminance upgraded color (i.e. from UpgradeToneMap()).
// This means single channel highlights must try harder to be bright.
//
// color_upgraded: Luminance upgraded Color to apply emulation.
// color_untonemapped: Color WITHOUT per-channel blowout.
// peak: The peak of the LDR tonemap curve. (Prob best 1.0 - 1.5)
// makeup: Simple multiplier after inverse luminance to compensate reduction. (prob best around 1.3)
// strength: Global strength of the effect. (prob best 0.25 - 0.35)
// cs: Color space for luminance.
// return: color_upgraded adjusted by the emulated luminance reduction.
float3 PerChannelTonemapLuminanceReductionEmulatation(float3 color_upgraded, float3 color_untonemapped, float peak = 1.0f, float makeup = 1.35f, float strength = 0.25f, uint cs = CS_BT709) {
  //compress perchannel
  color_untonemapped = Neutwo(color_untonemapped, peak);
  color_untonemapped = min(color_untonemapped, peak); //clip

  //inverse luminance
  float y = GetLuminance(color_untonemapped, cs);
  float y1 = NeutwoI(y, peak);
  y1 *= makeup; //makeup

  //ratio
  float y2 = GetLuminance(color_upgraded, CS_BT709);
  float ratio = y1 / y2;
  ratio = lerp(1, ratio, saturate(y2 * 2)); //high pass
  ratio = lerp(1, ratio, strength); //global
  
  //apply
  return color_upgraded * ratio;
}
///////////////////////////////////////////////////////////////////////////////////////////////////