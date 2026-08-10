#define LUT_3D 1
#include "./Includes/Common.hlsl"
#include "../Includes/ColorGradingLUT.hlsl"

struct ToneMapInfo {
  float3 x;      // HDR output
  float3 sdr;    // SDR Hable
  float  pDelta; // HDR peak delta
  float  p;      // HDR peak, adjusted by pDelta
};
static ToneMapInfo tmi = {float3(0,0,0), float3(0,0,0), 1.0, 1.0};

struct TexTuple {
  Texture3D<float4> t;
  SamplerState s;
};

void SetColor(float3 x) {
  tmi.x = x;
}

void CalcPeakDeltaByLut(TexTuple lut) {
  #if ALLOW_COLORGRADE == 0
    return;
  #endif

  float d = max3(lut.t.Sample(lut.s, 1).xyz);
  if (d > 0) tmi.pDelta /= d;
}

// x: linear HDR color
// pDelta: scaler on peak
void Rolloff() {
  // exposure 1
  tmi.x *= PS_REG_COMMON_HDR_PARAMS.x;

  // Hable
  float3 sdr;
  float3 num1 = tmi.x * (0.100000001 * tmi.x + 0.0500000007) + 0.00400000019;
  float3 den1 = tmi.x * (0.100000001 * tmi.x + 0.5) + 0.0599999987;
  sdr = num1 / den1;
  sdr -= 0.0666666701;
  sdr - max(0, sdr);
  tmi.sdr = sdr;

  // SDR early out
  [branch]
  if (!HDR_ENABLED) {
    tmi.x *= PS_REG_COMMON_HDR_PARAMS.z;
    tmi.x = min(tmi.x, 1.0);
    return;
  }

  // extended per channel
  float3 ext = tmi.x;
  tmi.p = GammaCorrectionPeak(HDR_PEAK * tmi.pDelta / max(PS_REG_COMMON_HDR_PARAMS.z, 1e-6));
  
  // ext *= 0.2f; // low slope of Hable https://www.desmos.com/calculator/7g0i1cnx5u
// float3 LinearPiecewiseExtension(float3 sdr, float3 hdr, float thres, float slope, float output)
  ext = LinearPiecewiseExtension(sdr, ext, 0.13, 0.200400533755, 0.0295591208569);

  // in B709
  float3 hdr709 = Neupow(ext, tmi.p, GS.WhiteClip); 

  // in BT2020 to generate more blowout naturally
  ext = BT709_To_BT2020(ext); 
  ext = NeupowHQ(ext, tmi.p, 1.46 * GS.WhiteClip);
  ext = BT2020_To_BT709(ext);

  // blend HDR and SDR
  sdr = UCS_Encode(sdr);
  ext = UCS_Encode(ext);
  hdr709 = UCS_Encode(hdr709);
  ext = RestoreHueAndChrominanceUcs(ext, hdr709, 0.267, 0.32, 0);
  // ext = RestoreHueAndChrominanceUcs(ext, sdr, 0.622, 0.622, 0.622);
  ext = RestoreHueAndChrominanceUcs(ext, sdr, 0.826, 0.826, 0.9);
  ext = UCS_Decode(ext);
  ext = max(ext, 0); //clean
  tmi.x = ext;

  // exposure 2 (linear white to clip, but just treat as exposure for HDR)
  tmi.x *= PS_REG_COMMON_HDR_PARAMS.z;
}

void LUT(TexTuple lut) {
  #if ALLOW_COLORGRADE == 0
    return;
  #endif

  // HDR: Compress
  float3 colorU = tmi.x;
  float3 colorN = colorU;
  if (HDR_ENABLED)
  {
    // luma compress
    float y = GetLuminance(colorN);
    float y1 = y;
    // y1 = Neupow(y1, 0.96, tmi.p, 1.);
    y1 = ReinhardClip(y1, 0.96, tmi.p); // max of input is HDR peak
    colorN *= safeDivision(y1, y, 0);

    // cram
    float m = max3(colorN);
    if (m > 1.0) colorN /= m;

    tmi.x = colorN;
  }
  
  // Sample 
  // TODO: variant w/ multiple LUTs
  tmi.x = SampleLUT(lut.t, lut.s, tmi.x, 16, true); // tetrahedral, else 16x linear BANDING TROLL!

  // HDR: Decompress
  if (HDR_ENABLED) {
    tmi.x = RestorePostProcess(colorU, colorN, tmi.x, 0, true);
    tmi.x = max(0, tmi.x);
    // tmi.x = min(tmi.x, HDR_PEAK); // very minor
  }
}

void GammaOut() {
  // Indirect Upgrade SRV Gamma Mismatch
  // tmi.x = sRGB_Encode(tmi.x);
}