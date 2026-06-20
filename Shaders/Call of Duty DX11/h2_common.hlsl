#include "common.hlsl"

///////////////////////////////////////////////////////////////////////////////////////////////////
// #ifdef COMMON_LUT
struct TMInfo
{
  float3 r0; //main color
  float3 r0HDR; //main color HDR
  float r0y; //main color luminance from HDR rolloff
  float ldrPeak; //UpgradeToneMap peak, useful because tint will shift it
};
static TMInfo tmi = { float3(0,0,0), float3(0,0,0), 0, 1 };

void TM_Color(float3 col) {
  col = max(0, col);
  tmi.r0 = col;
}

void TM_Rolloff() {
  float3 x = tmi.r0;
  float3 colorT, colorU;

  // SDR
  float3 lower = MobiusRolloff(x, cb4[2]); //when thres = \inf
  lower = max(lower, 0); //clean
  float3 upper = MobiusRolloff(x, cb4[1]); //when thres = 0
  colorT = x < cb4[0].x ? lower : upper; //piecewise point/threshold

  // HDR
  float4 c = cb4[0].x > 0 ? cb4[2] : cb4[1]; //use lower unless threshold is 0
  float slope_at_piecewise = MobiusRolloffDerivative(cb4[0].x, c); 
  float output_at_piecewise = MobiusRolloff(cb4[0].x, c);
  float3 lower_hdr = lower; //from SDR
  float3 upper_hdr = slope_at_piecewise * (x - cb4[0].x) + output_at_piecewise; //mx + b
  colorU = x < cb4[0].x ? lower_hdr : upper_hdr;

  // HDR out
  tmi.r0y = GetLuminance(colorU, CS_BT709);

  // HDR Blowout
  const float p = HDR_PEAK;
  colorU = Reinhard::ReinhardPiecewise(colorU, p, output_at_piecewise);
  // colorU = GTTonemapNoToe(colorU, p, output_at_piecewise);
  tmi.r0HDR = colorU;

  // Blend HDR Blowout onto SDR
  // if (DVS2) {
  //   colorU = UCS_ToUCS(colorU);
  //   colorT = UCS_ToUCS(colorT);
  //   // colorT = RestoreHueAndChrominanceUcs(colorT, colorU, 0.475, 0.8, 1);
  //   colorT = RestoreHueAndChrominanceUcs(colorT, colorU, 1, 1, 1);
  //   colorT = UCS_FromUCS(colorT);
  // } else {
    float colorTy = GetLuminance(colorT, CS_BT709);
    float colorUy = GetLuminance(colorU, CS_BT709);
    colorT = colorU * safeDivision(colorTy, colorUy, 1); //this gives less chroma than RestoreHueAndChrominanceUcs @ 1
  // }

  // SDR Clean
  colorT = max(colorT, 0);
  colorT = ClampByMaxChannel(colorT, 1); //(ensure max chrominance)

  // Gamma thing idk, not/barely used
  colorT = pow(colorT, cb4[3].z);

  // SDR out
  tmi.r0 = colorT;
}

void TM_LumaThingy() {
  float3 r1;

  r1.x = saturate(dot(tmi.r0, cb4[65].xyz));
  r1.y = saturate(dot(tmi.r0, cb4[66].xyz));
  r1.z = saturate(dot(tmi.r0, cb4[67].xyz));

  tmi.r0 = r1;
}

void TM_Gamma() {
  tmi.r0 = linear_to_sRGB_gamma(tmi.r0, GCT_NONE);
}

float3 TM_Tint_Internal(float3 x, float l) {
  float3 r1 = cb2[2].xyz * l + cb2[1].xyz;
  r1 = r1 * l + cb2[0].xyz;
  x = x * r1 + cb2[3].xyz;
  return x;
}

void TM_SaturationAndTint() {
  // return; //debug

  // Setup
  float4 r0, r1;
  r0.xyz = tmi.r0;
  
  // Saturation
  r0.w = saturate(dot(r0.xyz, float3(0.298999995,0.587000012,0.114)));
  r1.xyz = r0.www + -r0.xyz;
  r1.w = cb2[1].w * r0.w + cb2[0].w;
  r0.xyz = r1.www * r1.xyz + r0.xyz;

  // Tint
  r0.xyz = TM_Tint_Internal(r0.xyz, r0.w);

  // Out 
  tmi.r0 = r0.xyz;
}

void TM_Upgrade() {
    tmi.r0 = gamma_sRGB_to_linear(tmi.r0, GCT_NONE); //linear

    // Upgrade()
    float ratio = 1.f;
    float y_untonemapped = tmi.r0y;
    float y_tonemapped = Neutwo(tmi.r0y, tmi.ldrPeak);
    float y_tonemapped_graded = GetLuminance(tmi.r0, CS_BT709);
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

    // Tonemap
    float p = HDR_PEAK;
    p = GammaCorrectionPeak(p);

    // y1 = Neutwo(y1, p);
    y1 = Reinhard::ReinhardPiecewise(y1, p, 0.18);
    // y1 = GTTonemapNoToe(y1, p, 0.18);

    // Apply
    tmi.r0 *= safeDivision(y1, y, 1);

    // Clamp
    tmi.r0 = clamp(tmi.r0, 0, p); //clean

    // Intermediate Scaling
    tmi.r0 *= HDR_INTSCALING; //TODO: move to after AA

    tmi.r0 = linear_to_sRGB_gamma(tmi.r0, GCT_NONE); //gamma
}
// #endif
///////////////////////////////////////////////////////////////////////////////////////////////////