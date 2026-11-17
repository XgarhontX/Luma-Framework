#include "./common1.hlsl"

cbuffer PostFxCBuffer : register(b8)
{
  float4 postFxControl0 : packoffset(c0);
  float4 postFxControl1 : packoffset(c1);
  float4 postFxBloom[26] : packoffset(c80);
}

cbuffer BloomCSConstants : register(b10)
{
  float4 BloomCS_OutSize;
  float BloomCS_Lod0;
  float BloomCS_Lod1;
  float2 BloomCS_Pad;
}

SamplerState biLinearClamp_s : register(s0);
Texture2D<float4> codeTexture0 : register(t0);
Texture2D<float4> codeTexture1 : register(t1);
RWTexture2D<float4> BloomCS_Out0 : register(u0);
RWTexture2D<float4> BloomCS_Out1 : register(u1);
RWTexture2D<float4> BloomCS_Out2 : register(u2);

#define BLOOM_CS_THREADS 8

static const float3 BLOOM_LUMA_WEIGHTS = float3(0.212599993, 0.715200007, 0.0722000003);

float2 BloomCS_UV(uint2 pixel)
{
  return (float2(pixel) + 0.5) * BloomCS_OutSize.zw;
}

float3 BloomCS_Tap(float2 uv, int2 offset)
{
  return codeTexture0.SampleLevel(biLinearClamp_s, uv, BloomCS_Lod0, offset).xyz;
}

float BloomCS_FastRcpOnePlusLuma(float3 c)
{
  return asfloat(0x7ef311c2 - asint(1.0 + dot(c, BLOOM_LUMA_WEIGHTS)));
}

float4 BloomCS_ExposureEncode(float3 k)
{
  float4 v = float4(postFxBloom[0].x * k, dot(k, postFxBloom[0].yzw));
  v = log2(5.55555534 * v);
  float4 lo = postFxBloom[1].xxxy * v;
  float4 hi = postFxBloom[1].zzzw * v;
  v = (v < 0.0) ? lo : hi;
  return 0.180000007 * exp2(v);
}

float BloomCS_FocusAlpha(uint2 pixel)
{
  float d = codeTexture1.Load(int3(pixel, 0)).x;
  float a = rcp(abs(d)) * 0.015625 + 0.984375;
  float b = 0.984375 * rcp(d);
  bool negative = d < 0.0;
  float y = negative ? a : b;
  float z = postFxControl0.z / y;
  float y2 = saturate(y * postFxControl0.x + postFxControl0.y);
  float z2 = postFxControl1.x * saturate(postFxControl0.w + z);
  return negative ? y2 : z2;
}

struct BloomCS_Taps13
{
  float3 c[13];
};
static const int2 BLOOM_TAPS13_OFFSETS[13] = {
  int2(-2, -2), int2(-2, 0), int2(0, 0), int2(0, -2), int2(2, -2), int2(2, 0), int2(2, 2), int2(0, 2), int2(-2, 2),
  int2(-1, -1), int2(1, -1), int2(-1, 1), int2(1, 1) };

BloomCS_Taps13 BloomCS_Sample13(float2 uv)
{
  BloomCS_Taps13 t;
  [unroll] for (int i = 0; i < 13; i++) t.c[i] = BloomCS_Tap(uv, BLOOM_TAPS13_OFFSETS[i]);
  return t;
}

float3 BloomCS_PartialKaris13(BloomCS_Taps13 t)
{
  float4 w[13];
  [unroll] for (int i = 0; i < 13; i++)
  {
    float wi = 1.0 / (1.0 + dot(t.c[i], BLOOM_LUMA_WEIGHTS));
    w[i] = float4(t.c[i] * wi, wi);
  }
  float4 A = w[0] + w[1] + w[2] + w[3];
  float4 B = w[2] + w[3] + w[4] + w[5];
  float4 C = w[2] + w[5] + w[6] + w[7];
  float4 D = w[2] + w[7] + w[8] + w[1];
  float4 E = w[9] + w[10] + w[11] + w[12];
  return 0.125 * (A.xyz / A.w + B.xyz / B.w + C.xyz / C.w + D.xyz / D.w) + 0.5 * (E.xyz / E.w);
}

float3 BloomCS_Plain13(BloomCS_Taps13 t)
{
  float3 outer = t.c[0] + t.c[1] + t.c[3] + t.c[4] + t.c[5] + t.c[6] + t.c[7] + t.c[8];
  float3 inner = t.c[9] + t.c[10] + t.c[11] + t.c[12];
  return outer * 0.0500000007 + (inner * 0.100000001 + t.c[2] * 0.200000003);
}

float3 BloomCS_Focus13(BloomCS_Taps13 t)
{
  float3 inner = t.c[9] + t.c[10] + t.c[11] + t.c[12];
  return (inner * 0.25 - t.c[2]) * 0.5 + t.c[2];
}

bool BloomCS_OutOfBounds(uint2 pixel)
{
  return any(pixel >= uint2(BloomCS_OutSize.xy));
}

[numthreads(BLOOM_CS_THREADS, BLOOM_CS_THREADS, 1)]
void cs_downsample_first(uint3 id : SV_DispatchThreadID)
{
  if (BloomCS_OutOfBounds(id.xy)) return;
  const float2 uv = BloomCS_UV(id.xy);

  float4 cross = 0, corners = 0, inner = 0;
#define BLOOM_FIRST_TAP(acc, off) { float3 c = max(0.0, BloomCS_Tap(uv, off)); float w = BloomCS_FastRcpOnePlusLuma(c); acc += w * float4(c, 1.0); }
  BLOOM_FIRST_TAP(cross, int2(2, 0));
  BLOOM_FIRST_TAP(cross, int2(0, 0));
  BLOOM_FIRST_TAP(cross, int2(-2, 0));
  BLOOM_FIRST_TAP(cross, int2(0, 2));
  BLOOM_FIRST_TAP(cross, int2(0, -2));
  BLOOM_FIRST_TAP(corners, int2(-2, -2));
  BLOOM_FIRST_TAP(corners, int2(2, -2));
  BLOOM_FIRST_TAP(corners, int2(-2, 2));
  BLOOM_FIRST_TAP(corners, int2(2, 2));
  BLOOM_FIRST_TAP(inner, int2(-1, -1));
  BLOOM_FIRST_TAP(inner, int2(1, -1));
  BLOOM_FIRST_TAP(inner, int2(-1, 1));
  BLOOM_FIRST_TAP(inner, int2(1, 1));
#undef BLOOM_FIRST_TAP
  float4 acc = cross * 0.0714285746 + corners * 0.0357142873 + inner * 0.125;
  BloomCS_Out0[id.xy] = float4(acc.xyz * rcp(acc.w), 1.0);
}

[numthreads(BLOOM_CS_THREADS, BLOOM_CS_THREADS, 1)]
void cs_downsample_l1(uint3 id : SV_DispatchThreadID)
{
  if (BloomCS_OutOfBounds(id.xy)) return;
  const float2 uv = BloomCS_UV(id.xy);
  BloomCS_Taps13 t = BloomCS_Sample13(uv);
  BloomCS_Out0[id.xy] = BloomCS_ExposureEncode(BloomCS_PartialKaris13(t));
  BloomCS_Out2[id.xy] = float4(BloomCS_Plain13(t), 1.0);
}

[numthreads(BLOOM_CS_THREADS, BLOOM_CS_THREADS, 1)]
void cs_downsample_l1_focus(uint3 id : SV_DispatchThreadID)
{
  if (BloomCS_OutOfBounds(id.xy)) return;
  const float2 uv = BloomCS_UV(id.xy);
  BloomCS_Taps13 t = BloomCS_Sample13(uv);
  BloomCS_Out0[id.xy] = BloomCS_ExposureEncode(BloomCS_PartialKaris13(t));
  BloomCS_Out1[id.xy] = float4(BloomCS_Focus13(t), BloomCS_FocusAlpha(id.xy));
}

[numthreads(BLOOM_CS_THREADS, BLOOM_CS_THREADS, 1)]
void cs_downsample_l1_focus_bloom(uint3 id : SV_DispatchThreadID)
{
  if (BloomCS_OutOfBounds(id.xy)) return;
  const float2 uv = BloomCS_UV(id.xy);
  BloomCS_Taps13 t = BloomCS_Sample13(uv);
  BloomCS_Out0[id.xy] = BloomCS_ExposureEncode(BloomCS_PartialKaris13(t));
  BloomCS_Out1[id.xy] = float4(BloomCS_Focus13(t), BloomCS_FocusAlpha(id.xy));
  BloomCS_Out2[id.xy] = float4(BloomCS_Plain13(t), 1.0);
}

[numthreads(BLOOM_CS_THREADS, BLOOM_CS_THREADS, 1)]
void cs_downsample_ev(uint3 id : SV_DispatchThreadID)
{
  if (BloomCS_OutOfBounds(id.xy)) return;
  const float2 uv = BloomCS_UV(id.xy);
  BloomCS_Taps13 t = BloomCS_Sample13(uv);
  BloomCS_Out0[id.xy] = BloomCS_ExposureEncode(BloomCS_PartialKaris13(t));
}

#ifndef BLOOM_BLUR_LEVEL
#define BLOOM_BLUR_LEVEL 1
#endif

#if BLOOM_BLUR_LEVEL == 1
  #define BLOOM_BLUR_HALF_TAPS 3
  static const float BLOOM_BLUR_OFFSETS[BLOOM_BLUR_HALF_TAPS] = { 1.46519995, 0.791599989, 0.366100013 };
#elif BLOOM_BLUR_LEVEL == 2
  #define BLOOM_BLUR_HALF_TAPS 4
  static const float BLOOM_BLUR_OFFSETS[BLOOM_BLUR_HALF_TAPS] = { 1.59319997, 0.967400014, 0.58950001, 0.282200009 };
#elif BLOOM_BLUR_LEVEL == 3
  #define BLOOM_BLUR_HALF_TAPS 5
  static const float BLOOM_BLUR_OFFSETS[BLOOM_BLUR_HALF_TAPS] = { 1.69060004, 1.09679997, 0.747900009, 0.472799987, 0.229900002 };
#elif BLOOM_BLUR_LEVEL == 4
  #define BLOOM_BLUR_HALF_TAPS 6
  static const float BLOOM_BLUR_OFFSETS[BLOOM_BLUR_HALF_TAPS] = { 1.76880002, 1.19840002, 0.869400024, 0.615100026, 0.395700008, 0.194000006 };
#else
  #define BLOOM_BLUR_HALF_TAPS 7
  static const float BLOOM_BLUR_OFFSETS[BLOOM_BLUR_HALF_TAPS] = { 1.83389997, 1.2816, 0.967400014, 0.727900028, 0.524399996, 0.340700001, 0.167899996 };
#endif

float3 BloomCS_BlurMip(float2 uv, float2 dir, float scale)
{
  float4 sum = codeTexture0.SampleLevel(biLinearClamp_s, uv, 0.0);
  [unroll] for (int i = 0; i < BLOOM_BLUR_HALF_TAPS; i++)
  {
    const float2 o = dir * (BLOOM_BLUR_OFFSETS[i] * scale);
    sum += codeTexture0.SampleLevel(biLinearClamp_s, uv - o, 0.0);
    sum += codeTexture0.SampleLevel(biLinearClamp_s, uv + o, 0.0);
  }
  const float invTaps = 1.0 / float(2 * BLOOM_BLUR_HALF_TAPS + 1);
  const float a = sum.w * invTaps;
  return postFxBloom[2 * BLOOM_BLUR_LEVEL].xyz * sum.xyz * invTaps + postFxBloom[2 * BLOOM_BLUR_LEVEL + 1].xyz * a;
}

float3 BloomCS_Final(float3 c)
{
  c = max(0.0, c);
#if CUSTOM_SDR == 0
  #if CUSTOM_BLOOM_TONEMAP == 0
    {
      float y = max(c.x, max(c.y, c.z));
      if (y > 0.0)
      {
        float y1 = Reinhard::ReinhardSimple(y, 1);
        c *= y1 / y;
      }
    }
  #elif CUSTOM_BLOOM_TONEMAP == 1
    c = Reinhard::Jodie(c, 1, 0.25, CS_BT709);
  #endif
#else
  c = Reinhard::ReinhardSimple(c, 1);
#endif

  c = sqrt(c);
  c = saturate(c * postFxBloom[12].xyz + postFxBloom[13].xyz);
  c = exp2(postFxBloom[14].xyz * log2(c));
  c = saturate(c * postFxBloom[15].xyz + postFxBloom[16].xyz);
  c = c * c;

  float3 r;
  r.x = postFxBloom[17].w + dot(c, postFxBloom[17].xyz);
  r.y = postFxBloom[18].w + dot(c, postFxBloom[18].xyz);
  r.z = postFxBloom[19].w + dot(c, postFxBloom[19].xyz);
  r = max(0.0, r);

  float3 o = EncodeRec709(r);
#if CUSTOM_SDR > 0
  o *= GS_Bloom;
#endif
  return o;
}

[numthreads(BLOOM_CS_THREADS, BLOOM_CS_THREADS, 1)]
void cs_blur_y(uint3 id : SV_DispatchThreadID)
{
  if (BloomCS_OutOfBounds(id.xy)) return;
  const float2 uv = BloomCS_UV(id.xy);
  uint w, h, mips;
  codeTexture0.GetDimensions(0, w, h, mips);
  const float scale = float(h) * (postFxBloom[19 + BLOOM_BLUR_LEVEL].y * postFxBloom[19 + BLOOM_BLUR_LEVEL].w);
  float3 c = BloomCS_BlurMip(uv, float2(0.0, 1.0), scale);
#if BLOOM_BLUR_LEVEL < 5
  c += codeTexture1.SampleLevel(biLinearClamp_s, uv, 0.0).xyz;
#endif
#if BLOOM_BLUR_LEVEL == 1
  c = BloomCS_Final(c);
#endif
  BloomCS_Out0[id.xy] = float4(c, 1.0);
}

[numthreads(BLOOM_CS_THREADS, BLOOM_CS_THREADS, 1)]
void cs_blur_x(uint3 id : SV_DispatchThreadID)
{
  if (BloomCS_OutOfBounds(id.xy)) return;
  const float2 uv = BloomCS_UV(id.xy);
  uint w, h, mips;
  codeTexture0.GetDimensions(0, w, h, mips);
  const float scale = float(w) * (postFxBloom[19 + BLOOM_BLUR_LEVEL].x * postFxBloom[19 + BLOOM_BLUR_LEVEL].z);
  float4 sum = codeTexture0.SampleLevel(biLinearClamp_s, uv, 0.0);
  [unroll] for (int i = 0; i < BLOOM_BLUR_HALF_TAPS; i++)
  {
    const float2 o = float2(BLOOM_BLUR_OFFSETS[i] * scale, 0.0);
    sum += codeTexture0.SampleLevel(biLinearClamp_s, uv - o, 0.0);
    sum += codeTexture0.SampleLevel(biLinearClamp_s, uv + o, 0.0);
  }
  BloomCS_Out0[id.xy] = sum * (1.0 / float(2 * BLOOM_BLUR_HALF_TAPS + 1));
}

#ifndef BLOOM_GAUSS_AXIS
#define BLOOM_GAUSS_AXIS 0
#endif

[numthreads(BLOOM_CS_THREADS, BLOOM_CS_THREADS, 1)]
void cs_gauss(uint3 id : SV_DispatchThreadID)
{
  if (BloomCS_OutOfBounds(id.xy)) return;
  const float2 uv = BloomCS_UV(id.xy);
#if BLOOM_GAUSS_AXIS == 0
  const float2 step = float2(postFxControl0.x, 0.0);
#else
  const float2 step = float2(0.0, postFxControl0.y);
#endif
#define BLOOM_GAUSS_PAIR(acc, k, weight) acc += (codeTexture0.SampleLevel(biLinearClamp_s, uv - step * (k), 0.0).xyz + codeTexture0.SampleLevel(biLinearClamp_s, uv + step * (k), 0.0).xyz) * (weight)

  float3 acc = codeTexture0.SampleLevel(biLinearClamp_s, uv, 0.0).xyz * 0.398942262;
  BLOOM_GAUSS_PAIR(acc, 1.0, 0.241970703);
  BLOOM_GAUSS_PAIR(acc, 2.0, 0.0539909601);
  BLOOM_GAUSS_PAIR(acc, 3.0, 0.00443184003);
  float norm = 0.999729276;
  if (postFxControl0.w > 3.0)
  {
    BLOOM_GAUSS_PAIR(acc, 0.5, 0.352065325);
    BLOOM_GAUSS_PAIR(acc, 1.5, 0.129517585);
    BLOOM_GAUSS_PAIR(acc, 2.5, 0.0175282899);
    norm = 1.99795175;
    if (postFxControl0.w > 9.0)
    {
      BLOOM_GAUSS_PAIR(acc, 0.25, 0.386668086);
      BLOOM_GAUSS_PAIR(acc, 0.75, 0.301137418);
      BLOOM_GAUSS_PAIR(acc, 1.25, 0.182649076);
      BLOOM_GAUSS_PAIR(acc, 1.75, 0.0862773135);
      BLOOM_GAUSS_PAIR(acc, 2.25, 0.0317396484);
      BLOOM_GAUSS_PAIR(acc, 2.75, 0.00909356028);
      norm = 3.99308205;
    }
  }
#undef BLOOM_GAUSS_PAIR
  BloomCS_Out0[id.xy] = float4(acc / norm, 1.0);
}
