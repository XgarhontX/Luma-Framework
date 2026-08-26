#define LUT_3D 1
// #define UCS_MODE 1
#include "./Includes/Common.hlsl"
#include "./Includes/PragMap.hlsl"
#include "./Includes/PragMap2.hlsl"
#include "../Includes/ColorGradingLUT.hlsl"

#define HALO3_TONEMAP 0

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

float3 Rolloff(float3 hdr) {
  // SDR early out
  if (!HDR_ENABLED) return saturate(hdr);

  // HDR
  float p = GammaCorrectionPeak(HDR_PEAK);
#if HALO3_TONEMAP == 0
  // Hue Correct
  float y0 = dot(hdr, Rec709_Luminance);
  hdr = NeupowHQ(hdr, p, 5 * GS.WhiteClip); // HDR Rolloff
  hdr = PragMap::hueShiftBezoldBrucke(hdr, 0.7614 * y0, 0.0459);
  hdr = max(0, hdr);

  // Path to White
  hdr /= p;
  hdr = sqrt(hdr);
  float y = dot(hdr, Rec709_Luminance * float3(0.8,0.87,1));
  // float m = dot(hdr, Rec709_Luminance * float3(0.1,0.1,10));
  hdr = lerp(hdr, y, smoothstep(0.726, 1, y) * 0.55);
  // hdr = lerp(hdr, y, smoothstep(0.719, 1, m) * 0.1125);
  hdr *= hdr;
  hdr *= p;

  hdr = max(hdr, 0);
#endif

  // Clean
  hdr = max(hdr, 0);
  hdr = min(hdr, p);

  return hdr;
}