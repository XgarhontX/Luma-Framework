#if CUSTOM_TAA == 0
cbuffer cb8_buf : register(b8)
{
    uint4 cb8_m0 : packoffset(c0);
    float4 cb8_m1 : packoffset(c1);
};

cbuffer cb1_buf : register(b1)
{
    uint4 cb1_m0 : packoffset(c0);
    uint4 cb1_m1 : packoffset(c1);
    uint4 cb1_m2 : packoffset(c2);
    uint4 cb1_m3 : packoffset(c3);
    uint4 cb1_m4 : packoffset(c4);
    uint4 cb1_m5 : packoffset(c5);
    uint4 cb1_m6 : packoffset(c6);
    uint4 cb1_m7 : packoffset(c7);
    uint4 cb1_m8 : packoffset(c8);
    uint4 cb1_m9 : packoffset(c9);
    uint4 cb1_m10 : packoffset(c10);
    uint4 cb1_m11 : packoffset(c11);
    uint4 cb1_m12 : packoffset(c12);
    uint4 cb1_m13 : packoffset(c13);
    uint4 cb1_m14 : packoffset(c14);
    uint4 cb1_m15 : packoffset(c15);
    uint4 cb1_m16 : packoffset(c16);
    uint4 cb1_m17 : packoffset(c17);
    uint4 cb1_m18 : packoffset(c18);
    uint4 cb1_m19 : packoffset(c19);
    uint4 cb1_m20 : packoffset(c20);
    uint4 cb1_m21 : packoffset(c21);
    uint4 cb1_m22 : packoffset(c22);
    uint4 cb1_m23 : packoffset(c23);
    uint4 cb1_m24 : packoffset(c24);
    uint4 cb1_m25 : packoffset(c25);
    uint4 cb1_m26 : packoffset(c26);
    uint4 cb1_m27 : packoffset(c27);
    uint4 cb1_m28 : packoffset(c28);
    uint4 cb1_m29 : packoffset(c29);
    uint4 cb1_m30 : packoffset(c30);
    uint4 cb1_m31 : packoffset(c31);
    uint4 cb1_m32 : packoffset(c32);
    uint4 cb1_m33 : packoffset(c33);
    uint4 cb1_m34 : packoffset(c34);
    uint4 cb1_m35 : packoffset(c35);
    uint4 cb1_m36 : packoffset(c36);
    uint4 cb1_m37 : packoffset(c37);
    uint4 cb1_m38 : packoffset(c38);
    uint4 cb1_m39 : packoffset(c39);
    uint4 cb1_m40 : packoffset(c40);
    uint4 cb1_m41 : packoffset(c41);
    uint4 cb1_m42 : packoffset(c42);
    uint4 cb1_m43 : packoffset(c43);
    float2 cb1_m44 : packoffset(c44);
    float2 cb1_m45 : packoffset(c44.z);
};

SamplerState s0 : register(s0);
Texture2D<float4> t0 : register(t0);
Texture2D<float4> t6 : register(t6);
Texture2D<float4> t7 : register(t7);
Texture2D<float4> t9 : register(t9);

static float2 TEXCOORD;
static float3 SV_TARGET;

struct SPIRV_Cross_Input
{
    float2 TEXCOORD : TEXCOORD0;
};

struct SPIRV_Cross_Output
{
    float3 SV_TARGET : SV_Target0;
};

float dp3_f32(float3 a, float3 b)
{
    precise float _76 = a.x * b.x;
    return mad(a.z, b.z, mad(a.y, b.y, _76));
}

float dp2_f32(float2 a, float2 b)
{
    precise float _64 = a.x * b.x;
    return mad(a.y, b.y, _64);
}

void frag_main()
{
    float _97 = mad(cb1_m45.x, 2.0f, TEXCOORD.x);
    float _98 = mad(cb1_m45.y, 2.0f, TEXCOORD.y);
    float _106 = mad(cb1_m45.x, -2.0f, TEXCOORD.x);
    float _107 = mad(cb1_m45.y, -2.0f, TEXCOORD.y);
    float4 _110 = t9.SampleLevel(s0, float2(_106, _107), 0.0f);
    float _111 = _110.x;
    float4 _115 = t9.SampleLevel(s0, float2(_106, _98), 0.0f);
    float _116 = _115.x;
    float4 _120 = t9.SampleLevel(s0, float2(_97, _107), 0.0f);
    float _121 = _120.x;
    float2 _123 = float2(TEXCOORD.x, TEXCOORD.y);
    float4 _125 = t9.SampleLevel(s0, _123, 0.0f);
    float _126 = _125.x;
    float _127 = max(max(_121, max(_116, max(_111, t9.SampleLevel(s0, float2(_97, _98), 0.0f).x))), _126);
    bool _128 = _127 == _111;
    bool _130 = _127 == _116;
    bool _131 = _127 == _121;
    bool _141 = _127 == _126;
    float4 _151 = t6.SampleLevel(s0, float2(_141 ? TEXCOORD.x : (((((!(_128 || _130)) || _131) ? 2.0f : (-2.0f)) * cb1_m45.x) + TEXCOORD.x), _141 ? TEXCOORD.y : (((((!(_130 || (!_128))) || _131) ? (-2.0f) : 2.0f) * cb1_m45.y) + TEXCOORD.y)), 0.0f);
    float _152 = _151.x;
    float _153 = _151.y;
    float _154 = abs(_152);
    float _155 = abs(_153);
    float _156 = _154 - 0.5f;
    float _157 = _155 - 0.5f;
    float _168 = mad(clamp(_156 + _156, 0.0f, 1.0f), 30.0f, min(_154 + _154, 1.0f) * 10.0f);
    float _169 = mad(clamp(_157 + _157, 0.0f, 1.0f), 30.0f, min(_155 + _155, 1.0f) * 10.0f);
    float _174 = (_152 >= 0.0f) ? _168 : (-_168);
    float _175 = (_153 >= 0.0f) ? _169 : (-_169);
    float _178 = mad(-cb1_m45.x, _174, TEXCOORD.x);
    float _179 = mad(-cb1_m45.y, _175, TEXCOORD.y);
    float4 _182 = t0.SampleLevel(s0, _123, 0.0f);
    float _183 = _182.x;
    float _184 = _182.y;
    float _185 = _182.z;
    float4 _189 = t7.SampleLevel(s0, float2(_178, _179), 0.0f);
    float _230 = clamp(mad(abs(dp3_f32(float3(asfloat((asint(_183 * 3.0517578125e-05f) >> int(1u)) + 532487669), asfloat((asint(_184 * 3.0517578125e-05f) >> int(1u)) + 532487669), asfloat((asint(_185 * 3.0517578125e-05f) >> int(1u)) + 532487669)), float3(0.2125999927520751953125f, 0.715200006961822509765625f, 0.072200000286102294921875f)) - dp3_f32(float3(asfloat((asint(_189.x * 3.0517578125e-05f) >> int(1u)) + 532487669), asfloat((asint(_189.y * 3.0517578125e-05f) >> int(1u)) + 532487669), asfloat((asint(_189.z * 3.0517578125e-05f) >> int(1u)) + 532487669)), float3(0.2125999927520751953125f, 0.715200006961822509765625f, 0.072200000286102294921875f))), 6.666666507720947265625f, -0.3333333432674407958984375f), 0.0f, 1.0f);
    if (_230 > 0.0f)
    {
        bool _237 = abs(_175) < abs(_174);
        float _242 = _178 * cb1_m44.x;
        float _243 = _179 * cb1_m44.y;
        float _244 = _237 ? _242 : _243;
        float _246 = floor(_244 - 0.5f);
        float _247 = _246 + 0.5f;
        float _248 = _244 - _247;
        float _249 = _248 * _248;
        float _253 = -_249;
        float _254 = mad(_253, _248, mad(_249, 2.0f, _247 - _244));
        float _259 = mad(_253, _248, mad(_248, _248, _248));
        float _260 = mad(_249, _248, _253);
        float _261 = _259 + (mad(_249, _248, -(_249 + _249)) + 1.0f);
        float _263 = _246 - 0.5f;
        float _264 = _246 + 2.5f;
        float _265 = _247 + (_259 / _261);
        float4 _278 = t7.SampleLevel(s0, float2((_237 ? _263 : _242) * cb1_m45.x, (_237 ? _243 : _263) * cb1_m45.y), 0.0f);
        float4 _284 = t7.SampleLevel(s0, float2((_237 ? _265 : _242) * cb1_m45.x, (_237 ? _243 : _265) * cb1_m45.y), 0.0f);
        float4 _298 = t7.SampleLevel(s0, float2((_237 ? _264 : _242) * cb1_m45.x, (_237 ? _243 : _264) * cb1_m45.y), 0.0f);
        float _302 = mad(_260, _298.x, mad(_254, _278.x, _261 * _284.x));
        float _303 = mad(_260, _298.y, mad(_254, _278.y, _261 * _284.y));
        float _304 = mad(_260, _298.z, mad(_254, _278.z, _261 * _284.z));
        float2 _305 = float2(_174, _175);
        float4 _317 = t0.SampleLevel(s0, float2(TEXCOORD.x - cb1_m45.x, TEXCOORD.y), 0.0f);
        float _318 = _317.x;
        float _319 = _317.y;
        float _320 = _317.z;
        float4 _323 = t0.SampleLevel(s0, float2(cb1_m45.x + TEXCOORD.x, TEXCOORD.y), 0.0f);
        float _324 = _323.x;
        float _325 = _323.y;
        float _326 = _323.z;
        float4 _331 = t0.SampleLevel(s0, float2(TEXCOORD.x, cb1_m45.y + TEXCOORD.y), 0.0f);
        float _332 = _331.x;
        float _333 = _331.y;
        float _334 = _331.z;
        float4 _337 = t0.SampleLevel(s0, float2(TEXCOORD.x, TEXCOORD.y - cb1_m45.y), 0.0f);
        float _338 = _337.x;
        float _339 = _337.y;
        float _340 = _337.z;
        float _350 = min(_183, min(_318, min(_324, min(_338, _332))));
        float _351 = min(_184, min(_319, min(_325, min(_339, _333))));
        float _352 = min(_185, min(_320, min(_326, min(_340, _334))));
        float _362 = max(max(_318, max(_324, max(_338, _332))), _183);
        float _363 = max(max(_319, max(_325, max(_339, _333))), _184);
        float _364 = max(max(_320, max(_326, max(_340, _334))), _185);
        float _377 = min(min(max(_362, _302), max(_362, _350)), max(_302, _350));
        float _378 = min(min(max(_363, _303), max(_363, _351)), max(_303, _351));
        float _379 = min(min(max(_364, _304), max(_364, _352)), max(_304, _352));
        float _396 = dp3_f32(float3(asfloat((asint(_350 * 3.0517578125e-05f) >> int(1u)) + 532487669), asfloat((asint(_351 * 3.0517578125e-05f) >> int(1u)) + 532487669), asfloat((asint(_352 * 3.0517578125e-05f) >> int(1u)) + 532487669)), float3(0.2125999927520751953125f, 0.715200006961822509765625f, 0.072200000286102294921875f));
        float _413 = dp3_f32(float3(asfloat((asint(_362 * 3.0517578125e-05f) >> int(1u)) + 532487669), asfloat((asint(_363 * 3.0517578125e-05f) >> int(1u)) + 532487669), asfloat((asint(_364 * 3.0517578125e-05f) >> int(1u)) + 532487669)), float3(0.2125999927520751953125f, 0.715200006961822509765625f, 0.072200000286102294921875f));
        float _434 = dp3_f32(float3(asfloat((asint(_377 * 3.0517578125e-05f) >> int(1u)) + 532487669), asfloat((asint(_378 * 3.0517578125e-05f) >> int(1u)) + 532487669), asfloat((asint(_379 * 3.0517578125e-05f) >> int(1u)) + 532487669)), float3(0.2125999927520751953125f, 0.715200006961822509765625f, 0.072200000286102294921875f));
        float _452 = max(_230, clamp(mad(abs(_396 - _413), 10.0f, -1.0f), 0.0f, 1.0f));
        float _457 = min(min((_452 * _452) * mad(_452, -2.0f, 3.0f), clamp(40.0f - asfloat((asint(dp2_f32(_305, _305)) >> int(1u)) + 532487669), 0.0f, 1.0f)), mad(cb8_m1.x - cb8_m1.y, min(min(abs(_413 - _434), abs(_396 - _434)) / max(_413 - _396, 9.9999999747524270787835121154785e-07f), 1.0f), cb8_m1.y));
        SV_TARGET.x = mad(_457, _377 - _183, _183);
        SV_TARGET.y = mad(_457, _378 - _184, _184);
        SV_TARGET.z = mad(_457, _379 - _185, _185);
    }
    else
    {
        SV_TARGET.x = _183;
        SV_TARGET.y = _184;
        SV_TARGET.z = _185;
    }
}

SPIRV_Cross_Output main(SPIRV_Cross_Input stage_input)
{
    TEXCOORD = stage_input.TEXCOORD;
    frag_main();
    SPIRV_Cross_Output stage_output;
    stage_output.SV_TARGET = SV_TARGET;
    return stage_output;
}
#else
#include "./Includes/Common.hlsl"
#include "./Includes/TAAResolve.hlsl"

cbuffer PostFxCBuffer : register(b8)
{
  float2 unusedJitter : packoffset(c0);
  float2 filmicWeightRange : packoffset(c0.z);
}

cbuffer PerSceneConsts : register(b1)
{
  float4 renderTargetSize : packoffset(c44);
}

SamplerState bilinearSampler : register(s0);
Texture2D<float4> colorTex : register(t0);
Texture2D<float4> velocityTex0 : register(t6);
Texture2D<float4> filmicHistoryTex : register(t7);
Texture2D<float4> depthTex : register(t9);

void main(
  float4 v0 : SV_POSITION0,
  float2 v1 : TEXCOORD0,
  out float3 o0 : SV_TARGET0)
{
  const float2 uv = v1.xy;
  const float2 px = renderTargetSize.zw;
  const float3 c = max(colorTex.SampleLevel(bilinearSampler, uv, 0).rgb, 0.0);
  o0 = c;

  const float2 velUV = TAA_DilateVelocityUV(depthTex, bilinearSampler, uv, px);
  const float2 d = TAA_DecodeVelocity(velocityTex0.SampleLevel(bilinearSampler, velUV, 0).xy);
  const float2 reprojUV = uv - d * px;
  if (any(reprojUV < 0.0) || any(reprojUV > 1.0)) return;

  const float3 fh = max(filmicHistoryTex.SampleLevel(bilinearSampler, reprojUV, 0).rgb, 0.0);
  const float trigger = saturate(abs(TAA_EncodeLuma(c) - TAA_EncodeLuma(fh)) * 6.66666651 - 0.333333343);
  if (trigger <= 0.0) return;

  const float3 cY = TAA_RGBToYCoCg(c);
  float3 boxMin, boxMax;
  TAA_NeighbourhoodBox(colorTex, bilinearSampler, uv, px, cY, boxMin, boxMax);
  const float3 hY = TAA_RGBToYCoCg(TAA_SampleHistory(filmicHistoryTex, bilinearSampler, reprojUV, renderTargetSize.xy, px));
  float clipAmount;
  const float3 hClipped = TAA_ClipAABB(boxMin, boxMax, hY, clipAmount);

  float w = min(trigger * trigger * (3.0 - 2.0 * trigger), saturate(40.0 - length(d)));
  const float centrality = min(boxMax.x - hClipped.x, hClipped.x - boxMin.x) / max(boxMax.x - boxMin.x, 1e-6);
  w = min(w, lerp(filmicWeightRange.y, filmicWeightRange.x, saturate(centrality)));
  w *= saturate(1.0 - clipAmount * (2.0 * 0.6));

  const float wc = (1.0 - w) / (1.0 + cY.x);
  const float wh = w / (1.0 + hClipped.x);
  o0 = max(TAA_YCoCgToRGB((cY * wc + hClipped * wh) / max(wc + wh, 1e-5)), 0.0);
}
#endif
