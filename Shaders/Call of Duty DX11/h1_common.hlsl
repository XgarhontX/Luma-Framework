#include "Includes/Common.hlsl"
#include "../Includes/Reinhard.hlsl"
#include "Includes/ictcp_portable.hlsl"

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
//https://github.com/clshortfuse/renodx/blob/main/src/shaders/tonemap/hermite_spline.hlsl
namespace HermiteSpline {
  float Rescale(float x, float x_min, float x_max, float y_min = 0, float y_max = 1, bool clamp = false) {
    float value = lerp(y_min, y_max, (x - x_min) / (x_max - x_min));
    if (clamp) {
      value = saturate(value);
    }
    return value;
  }
  float HermiteSplineRolloff(float input, float target_white = 1.f, float max_white = 20.f) {
    float l_w = max_white;
    // float l_b = min_black;
    // float l_min = target_black;
    float l_max = target_white;
    float e_1 = Rescale(input, 0, l_w);
    // float min_lum = Rescale(l_min, l_b, l_w);
    float max_lum = Rescale(l_max, 0, l_w);
    float knee_start = 1.5f * max_lum - 0.5f;
    // float b = min_lum;
    float t_b = Rescale(e_1, knee_start, 1.f);

    // float p_e1 = (((2 * t_b * t_b * t_b) - (3 * t_b * t_b) + 1) * knee_start)
    //              + (((t_b * t_b * t_b) - (2 * t_b * t_b) + t_b) * (1.f - knee_start))
    //              + ((-(2 * t_b * t_b * t_b) + (3 * t_b * t_b)) * max_lum);
    float t_b_squared = t_b * t_b;
    float t_b_cubed = t_b_squared * t_b;
    float two_t_b_cubed = 2.f * t_b_cubed;
    float three_t_b_squared = 3.f * t_b_squared;
    float p_e1_h00 = (two_t_b_cubed - three_t_b_squared + 1.f);
    float p_e1_h10 = (t_b_cubed - 2.f * t_b_squared + t_b);
    float p_e1_h01 = (-two_t_b_cubed + three_t_b_squared);
    // float p_e1_h11 = (t_b_cubed - t_b_squared); // Not used since derivative is 0 at max_lum

    float p_e1 = p_e1_h00 * knee_start
                 + p_e1_h10 * (1.f - knee_start)
                 + p_e1_h01 * max_lum;

    float e_2 = (e_1 < knee_start) ? e_1 : p_e1;

    // float e_3 = e_2 + b * pow(1-e_2, 4);
    // float e_3a1 = (1 - e_2) * (1 - e_2);
    // float e_3a2 = e_3a1 * (1 - e_2);
    float e_3 = e_2;

    // Custom: clamp before lerp
    // e_3 = saturate(e_3);

    // float e_4 = lerp(l_b, l_w, e_3);
    float e_4 = l_w * e_3;

    return min(e_4, target_white);
  }
  float3 HermiteSplinePerChannelRolloff(float3 input, float target_white = 1.f, float max_white = 20.f) {
    float target_white_log2 = log2(target_white);
    float max_white_log2 = log2(max_white);
    float3 scaled = float3(
        input.r == 0 ? 0 : exp2(HermiteSplineRolloff(log2(input.r), target_white_log2, max_white_log2)),
        input.g == 0 ? 0 : exp2(HermiteSplineRolloff(log2(input.g), target_white_log2, max_white_log2)),
        input.b == 0 ? 0 : exp2(HermiteSplineRolloff(log2(input.b), target_white_log2, max_white_log2)));
    return scaled;
  }

  float HermiteSplineLuminanceRolloff(float luminance, float target_white = 1.f, float max_white = 20.f) {
    if (luminance <= 0) return 0;
    return exp2(HermiteSplineRolloff(log2(luminance), log2(target_white), log2(max_white)));
  }
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
#ifdef COMMON_LUT
struct LUTInfo
{
  float colorUy; //luma saved from rolloff pass prior
  float3 r0; //main color
  float r0y; //luminance for saturation and tint
  float ldrPeak; //UpgradeToneMap peak, useful because tint will shift it
};
static LUTInfo li = { 0, float3(0,0,0), 0, 1 };

void LUT_Color(float2 v1) {
  float4 col = t4.Sample(s4_s, v1.xy);
  li.colorUy = col.w; //luma saved from rolloff pass
  li.r0 = saturate(col.xyz); //clean
  // li.r0 = li.colorUy; //debug
}

void LUT_Gamma() {
  li.r0 = linear_to_sRGB_gamma(li.r0, GCT_NONE);
}

void LUT_LUT(Texture3D lut, SamplerState lutS) {
  // return; //debug

  const float strength = 0.9/* DVS3 */; 
  float3 r0Before = li.r0;

  li.r0 = li.r0 * 0.96875 + 0.015625; //pad (32x)
  li.r0 = lut.Sample(lutS, li.r0).xyz; //a cached texture for whole level

  //fix white point
  {
    float3 lut1 = lut.Load(int4(31,31,31,0)).xyz;
    float lutMax = max(lut1.x, max(lut1.y, lut1.z));
    float ratio = 1 / lutMax;
    li.r0 *= ratio;
  }

  li.r0 = lerp(r0Before, li.r0, saturate(1-pow(r0Before, 3.5) + 1-strength) * strength);

  // midgray change
  // {
  //   float mg_in = 0.46 * 0.96875 + 0.015625;
  //   float3 mg = lut.Sample(lutS, mg_in).xyz;
  //   mg = gamma_sRGB_to_linear(mg, GCT_NONE);
  //   float mg_luma = GetLuminance(mg, CS_BT709);
  //   float ratio = safeDivision(mg_luma, 0.18, 1);
  //   li.colorUy *= ratio;
  // }
}

float3 LUT_Tint_Internal(float3 x, float l) {
  float3 r1 = cb2[2].xyz * l + cb2[1].xyz;
  r1 = r1 * l + cb2[0].xyz;
  x = x * r1 + cb2[3].xyz;
  return x;
}

void LUT_SaturationAndTint() {
  // return; //debug

  float4 r0, r1; 
  li.r0y = dot(li.r0, float3(0.298999995,0.587000012,0.114));

  //sat
  r1.x = cb2[1].w * li.r0y + cb2[0].w;
  li.r0y = saturate(li.r0y);
  r1.yzw = li.r0y + -li.r0;
  li.r0 = r1.x * r1.yzw + li.r0;
  li.r0 = max(li.r0, 0); //clean

  //tint (user brighntess, overshoots SDR)
  li.r0 = LUT_Tint_Internal(li.r0, li.r0y);
  li.r0 = max(li.r0, 0); //clean

  //tint midgray change
  {
    float mg_in = 0.46;
    float3 mg = LUT_Tint_Internal(float3(mg_in, mg_in, mg_in), mg_in);
    mg = gamma_sRGB_to_linear(mg, GCT_NONE);
    float mg_luma = GetLuminance(mg, CS_BT709);
    float ratio = safeDivision(mg_luma, 0.18, 1);
    li.colorUy *= ratio;
  }

  //tint peak change
  {
    float3 peak = LUT_Tint_Internal(1, 1);
    float peak_max = max(peak.x, max(peak.y, peak.z));
    peak_max = gamma_sRGB_to_linear1(peak_max, GCT_NONE);
    li.ldrPeak = peak_max;
    li.colorUy *= peak_max;
  }
}

void LUT_Overlay(float2 w1, Texture2D overlayTex, SamplerState overlayS) {
  float3 r1 = float3(1,1,1) + -li.r0; //bruh what?! Tint overshoots, so this won't cause errors?
  float3 r2 = overlayTex.Sample(overlayS, w1.xy).xyz;
  li.r0 = r2 * r1 + li.r0;
}

void LUT_UpgradeAndTonemap() {
    li.r0 = gamma_sRGB_to_linear(li.r0, GCT_NONE); //linear

    float ratio = 1.f;
    float y_untonemapped = li.colorUy;
    float y_tonemapped = Neutwo(li.colorUy, li.ldrPeak);
    float y_tonemapped_graded = GetLuminance(li.r0, CS_BT709);

    if (y_untonemapped < y_tonemapped) {
      ratio = y_untonemapped / y_tonemapped;
    } else {
      float y_delta = y_untonemapped - y_tonemapped;
      y_delta = max(0, y_delta);
      const float y_new = y_tonemapped_graded + y_delta;

      const bool y_valid = (y_tonemapped_graded > 0);
      ratio = y_valid ? (y_new / y_tonemapped_graded) : 0;
    }

    float y = y_tonemapped_graded;
    float y1 = y;
    y1 *= ratio;

    float p = HDR_PEAK;
    p = gamma_sRGB_to_linear1(pow(p, 1 / 2.2));

    // y1 = Reinhard::ReinhardSimple(y1, p);
    // y1 = Neutwo(y1, p, p * log2(p) * 4);
    // y1 = HermiteSpline::HermiteSplineLuminanceRolloff(y1, p, p * log2(p));
    // y1 = GTTonemap(y1, p, 1, 0.26, 0.4, 1, 0);

    li.r0 *= safeDivision(y1, y, 1);

    // if (DVS1 == 0) li.r0 = Neutwo(li.r0, p);
    // else if (DVS1 < 0.25) li.r0 = GTTonemapNoToe(li.r0, p, 0.18); //BRUh, but this gives the BEST perchannel blowout to white.
    // else if (DVS1 < 0.5) li.r0 = ExponentialRollOff(li.r0, 0.18, p);
    // else if (DVS1 < 0.75) /* li.r0 = li.r0 / (li.r0 / p + 1); */Reinhard::ReinhardPiecewise(li.r0, p, 0.18);
    li.r0 = Reinhard::ReinhardPiecewise(li.r0, p, 0.26);
    // li.r0 = Reinhard::ReinhardSimple(li.r0, p);

    li.r0 = min(li.r0, p); //clean

    li.r0 = pow(linear_to_sRGB_gamma(li.r0, GCT_NONE), 2.2);

    // li.r0 = NeutwoI(min(1, li.r0), DVS3, DVS4);
    // li.r0 = min(li.r0, HDR_PEAK); //clean

    li.r0 *= HDR_INTSCALING; //TODO: move to after AA

    li.r0 = linear_to_sRGB_gamma(li.r0, GCT_NONE); //gamma
}
#endif
///////////////////////////////////////////////////////////////////////////////////////////////////