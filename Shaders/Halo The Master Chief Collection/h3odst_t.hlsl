#define LUT_3D 1
#include "./Includes/Common.hlsl"
#include "../Includes/ColorGradingLUT.hlsl"

struct ToneMapInfo {
  float3 x;   // HDR output
  float3 sdr; // SDR Hable
  float  p;   // HDR peak, adjusted by delta
};
static ToneMapInfo tmi = {float3(0,0,0), float3(0,0,0), 1.0};

struct TexTuple {
  Texture3D<float4> t;
  SamplerState s;
};

void SetColor(float3 x) {
  tmi.x = x;
}

float Rolloff_Root(float4 c) {
  //-\frac{c_{z}}{3c_{w}}
  return -c.z / (3.0 * c.w);
}
float Rolloff_Accel(float x, float4 c) {
  //6c_{w}x+2c_{z}
  return 6.0 * c.w * x + 2.0 * c.z;
}
float Rolloff_Vel(float x, float4 c) {
  //3c_{w}x^{2}+2c_{z}x+c_{y}
  return 3.0 * c.w * x * x + 2.0 * c.z * x + c.y;
}
float Rolloff_Vel_1Abs(float4 c) { //Breaks when c.w >= 0 || c.y <= 0. Also mirrored, where positive is useful.
  //\frac{-c_{z}+\sqrt{\left(c_{z}\right)^{2}-3c_{w}\left(c_{y}-1\right)}}{3c_{w}}
  if (c.w >= 0 || c.y <= 0) return 0.0;
  return abs((c.z + sqrt(c.z * c.z - 3.0 * c.w * (c.y - 1.0))) / (3.0 * c.w));
}
float Rolloff_Pos(float x, float4 c) {
  //c_{w}x^{3}+c_{z}x^{2}+c_{y}x
  return ((c.w * x + c.z) * x + c.y) * x;
}
float3 Rolloff_Pos(float3 x, float4 c) {
  //c_{w}x^{3}+c_{z}x^{2}+c_{y}x
  return ((c.w * x + c.z) * x + c.y) * x;
}

// c: tone_curve_constants
// https://www.desmos.com/calculator/1kdzfkobf7
void Rolloff(float4 c) {
  // SDR
  tmi.sdr = Rolloff_Pos(min(c.x, tmi.x), c);

  // SDR early out
  if (!HDR_ENABLED) {
    tmi.x = tmi.sdr;
    return;
  }

  // HDR Setup
  float slope_at_piecewise;
  float thres_at_piecewise;
  float output_at_piecewise;

  // HDR Threshold
  float root = Rolloff_Root(c);
  thres_at_piecewise = clamp(root, 0, c.x);
  if (thres_at_piecewise <= 0) thres_at_piecewise = Rolloff_Vel_1Abs(c); //find when compression (slope < 1) starts

  // HDR Slope & Output
  if (thres_at_piecewise > 0) {
    slope_at_piecewise = Rolloff_Vel(root, c);
    output_at_piecewise = Rolloff_Pos(thres_at_piecewise, c);
  } else {
    slope_at_piecewise = 1;
    output_at_piecewise = 0;
  }

  // HDR Extended 
  tmi.x = LinearPiecewiseExtension(tmi.sdr, tmi.x, thres_at_piecewise, slope_at_piecewise, output_at_piecewise);
  tmi.x = max(tmi.x, 0);

  // HDR Rolloff
  tmi.p = GammaCorrectionPeak(HDR_PEAK);
  tmi.x = NeupowHQ(tmi.x, tmi.p, 8 * GS.WhiteClip); // TODO: user white clip
}

void GammaOut() {
  // Indirect Upgrade SRV Gamma Mismatch
  // tmi.x = sRGB_Encode(tmi.x);
}