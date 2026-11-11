#if CUSTOM_TAA == 0
cbuffer cb8_buf : register(b8)
{
    float2 cb8_m0 : packoffset(c0);
    float2 cb8_m1 : packoffset(c0.z);
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

RWStructuredBuffer<uint2> u6 : register(u6);
SamplerState s0 : register(s0);
Texture2D<float4> t0 : register(t0);
Texture2D<float4> t6 : register(t6);
Texture2D<float4> t7 : register(t7);
Texture2D<float4> t9 : register(t9);
Texture2D<float4> t10 : register(t10);
Texture2D<float4> t11 : register(t11);
Texture2D<float4> t12 : register(t12);
Texture2D<float4> t14 : register(t14);
Texture2D<float4> t15 : register(t15);

static float4 gl_FragCoord;
static float2 TEXCOORD;
static float3 SV_TARGET;
static float SV_TARGET1;
static float3 SV_TARGET2;

struct SPIRV_Cross_Input
{
    float2 TEXCOORD : TEXCOORD0;
    float4 gl_FragCoord : SV_Position;
};

struct SPIRV_Cross_Output
{
    float3 SV_TARGET : SV_Target0;
    float SV_TARGET1 : SV_Target1;
    float3 SV_TARGET2 : SV_Target2;
};

uint spvPackHalf2x16(float2 value)
{
    uint2 Packed = f32tof16(value);
    return Packed.x | (Packed.y << 16);
}

float2 spvUnpackHalf2x16(uint value)
{
    return f16tof32(uint2(value & 0xffff, value >> 16));
}

uint spvBitfieldInsert(uint Base, uint Insert, uint Offset, uint Count)
{
    uint Mask = Count == 32 ? 0xffffffff : (((1u << Count) - 1) << (Offset & 31));
    return (Base & ~Mask) | ((Insert << Offset) & Mask);
}

uint2 spvBitfieldInsert(uint2 Base, uint2 Insert, uint Offset, uint Count)
{
    uint Mask = Count == 32 ? 0xffffffff : (((1u << Count) - 1) << (Offset & 31));
    return (Base & ~Mask) | ((Insert << Offset) & Mask);
}

uint3 spvBitfieldInsert(uint3 Base, uint3 Insert, uint Offset, uint Count)
{
    uint Mask = Count == 32 ? 0xffffffff : (((1u << Count) - 1) << (Offset & 31));
    return (Base & ~Mask) | ((Insert << Offset) & Mask);
}

uint4 spvBitfieldInsert(uint4 Base, uint4 Insert, uint Offset, uint Count)
{
    uint Mask = Count == 32 ? 0xffffffff : (((1u << Count) - 1) << (Offset & 31));
    return (Base & ~Mask) | ((Insert << Offset) & Mask);
}

uint spvBitfieldUExtract(uint Base, uint Offset, uint Count)
{
    uint Mask = Count == 32 ? 0xffffffff : ((1 << Count) - 1);
    return (Base >> Offset) & Mask;
}

uint2 spvBitfieldUExtract(uint2 Base, uint Offset, uint Count)
{
    uint Mask = Count == 32 ? 0xffffffff : ((1 << Count) - 1);
    return (Base >> Offset) & Mask;
}

uint3 spvBitfieldUExtract(uint3 Base, uint Offset, uint Count)
{
    uint Mask = Count == 32 ? 0xffffffff : ((1 << Count) - 1);
    return (Base >> Offset) & Mask;
}

uint4 spvBitfieldUExtract(uint4 Base, uint Offset, uint Count)
{
    uint Mask = Count == 32 ? 0xffffffff : ((1 << Count) - 1);
    return (Base >> Offset) & Mask;
}

int spvBitfieldSExtract(int Base, int Offset, int Count)
{
    int Mask = Count == 32 ? -1 : ((1 << Count) - 1);
    int Masked = (Base >> Offset) & Mask;
    int ExtendShift = (32 - Count) & 31;
    return (Masked << ExtendShift) >> ExtendShift;
}

int2 spvBitfieldSExtract(int2 Base, int Offset, int Count)
{
    int Mask = Count == 32 ? -1 : ((1 << Count) - 1);
    int2 Masked = (Base >> Offset) & Mask;
    int ExtendShift = (32 - Count) & 31;
    return (Masked << ExtendShift) >> ExtendShift;
}

int3 spvBitfieldSExtract(int3 Base, int Offset, int Count)
{
    int Mask = Count == 32 ? -1 : ((1 << Count) - 1);
    int3 Masked = (Base >> Offset) & Mask;
    int ExtendShift = (32 - Count) & 31;
    return (Masked << ExtendShift) >> ExtendShift;
}

int4 spvBitfieldSExtract(int4 Base, int Offset, int Count)
{
    int Mask = Count == 32 ? -1 : ((1 << Count) - 1);
    int4 Masked = (Base >> Offset) & Mask;
    int ExtendShift = (32 - Count) & 31;
    return (Masked << ExtendShift) >> ExtendShift;
}

float dp3_f32(float3 a, float3 b)
{
    precise float _164 = a.x * b.x;
    return mad(a.z, b.z, mad(a.y, b.y, _164));
}

float dp4_f32(float4 a, float4 b)
{
    precise float _147 = a.x * b.x;
    return mad(a.w, b.w, mad(a.z, b.z, mad(a.y, b.y, _147)));
}

float dp2_f32(float2 a, float2 b)
{
    precise float _136 = a.x * b.x;
    return mad(a.y, b.y, _136);
}

int cvt_f32_i32(float v)
{
    return isnan(v) ? 0 : ((v < (-2147483648.0f)) ? int(0x80000000) : ((v > 2147483520.0f) ? 2147483647 : int(v)));
}

uint f32_to_f16(float2 v)
{
    return spvPackHalf2x16(float2((abs(v.x) <= 3.4028234663852885981170418348452e+38f) ? clamp(v.x, -65504.0f, 65504.0f) : v.x, (abs(v.y) <= 3.4028234663852885981170418348452e+38f) ? clamp(v.y, -65504.0f, 65504.0f) : v.y));
}

uint cvt_f32_u32(float v)
{
    return (v > 4294967040.0f) ? 4294967295u : uint(max(v, 0.0f));
}

void frag_main()
{
    float _185 = mad(cb1_m45.x, 2.0f, TEXCOORD.x);
    float _186 = mad(cb1_m45.y, 2.0f, TEXCOORD.y);
    float _194 = mad(cb1_m45.x, -2.0f, TEXCOORD.x);
    float _195 = mad(cb1_m45.y, -2.0f, TEXCOORD.y);
    float4 _198 = t15.SampleLevel(s0, float2(_194, _195), 0.0f);
    float _199 = _198.x;
    float4 _203 = t15.SampleLevel(s0, float2(_194, _186), 0.0f);
    float _204 = _203.x;
    float _206 = -cb1_m45.x;
    float4 _210 = t15.SampleLevel(s0, float2(_185, _195), 0.0f);
    float _211 = _210.x;
    float4 _215 = t15.SampleLevel(s0, float2(TEXCOORD.x, TEXCOORD.y), 0.0f);
    float _216 = _215.x;
    float _217 = max(max(_211, max(_204, max(_199, t15.SampleLevel(s0, float2(_185, _186), 0.0f).x))), _216);
    bool _218 = _217 == _199;
    bool _219 = _217 == _204;
    bool _220 = _217 == _211;
    bool _230 = _217 == _216;
    float4 _240 = t11.SampleLevel(s0, float2(_230 ? TEXCOORD.x : (((((!(_218 || _219)) || _220) ? 2.0f : (-2.0f)) * cb1_m45.x) + TEXCOORD.x), _230 ? TEXCOORD.y : (((((!((!_218) || _219)) || _220) ? (-2.0f) : 2.0f) * cb1_m45.y) + TEXCOORD.y)), 0.0f);
    float _241 = _240.x;
    float _242 = _240.y;
    float _243 = abs(_241);
    float _244 = abs(_242);
    float _245 = _243 - 0.5f;
    float _246 = _244 - 0.5f;
    float _257 = mad(clamp(_245 + _245, 0.0f, 1.0f), 30.0f, min(_243 + _243, 1.0f) * 10.0f);
    float _258 = mad(clamp(_246 + _246, 0.0f, 1.0f), 30.0f, min(_244 + _244, 1.0f) * 10.0f);
    float _263 = (_241 >= 0.0f) ? _257 : (-_257);
    float _264 = (_242 >= 0.0f) ? _258 : (-_258);
    float _265 = _263 * cb1_m45.x;
    float _266 = _264 * cb1_m45.y;
    float _267 = -cb1_m45.y;
    float _268 = mad(_206, _263, TEXCOORD.x);
    float _269 = mad(_267, _264, TEXCOORD.y);
    float2 _271 = float2(_268, _269);
    float4 _273 = t12.SampleLevel(s0, _271, 0.0f);
    float _274 = _273.x;
    float _275 = _273.y;
    float _276 = abs(_274);
    float _277 = abs(_275);
    float _278 = _276 - 0.5f;
    float _279 = _277 - 0.5f;
    float _290 = mad(clamp(_278 + _278, 0.0f, 1.0f), 30.0f, min(_276 + _276, 1.0f) * 10.0f);
    float _291 = mad(clamp(_279 + _279, 0.0f, 1.0f), 30.0f, min(_277 + _277, 1.0f) * 10.0f);
    float _296 = (_274 >= 0.0f) ? _290 : (-_290);
    float _297 = (_275 >= 0.0f) ? _291 : (-_291);
    float4 _308 = t0.SampleLevel(s0, float2(TEXCOORD.x + cb8_m0.x, TEXCOORD.y + cb8_m0.y), 0.0f);
    float _309 = _308.x;
    float _310 = _308.y;
    float _311 = _308.z;
    float4 _321 = t6.SampleLevel(s0, float2(_268 + cb8_m1.x, _269 + cb8_m1.y), 0.0f);
    float _322 = _321.x;
    float _323 = _321.y;
    float _324 = _321.z;
    float _341 = dp3_f32(float3(asfloat((asint(_309 * 3.0517578125e-05f) >> int(1u)) + 532487669), asfloat((asint(_310 * 3.0517578125e-05f) >> int(1u)) + 532487669), asfloat((asint(_311 * 3.0517578125e-05f) >> int(1u)) + 532487669)), float3(0.2125999927520751953125f, 0.715200006961822509765625f, 0.072200000286102294921875f));
    float4 _367 = t7.GatherRed(s0, _271);
    float _372 = mad(_206, _296, _268);
    float _373 = mad(_267, _297, _269);
    float4 _379 = t10.GatherRed(s0, float2(_372 - mad(mad(cb1_m45.x, _296, -_265), 2.0f, _265), _373 - mad(mad(cb1_m45.y, _297, -_266), 2.0f, _266)));
    float _406 = min(max(mad(-abs(_341 - t9.SampleLevel(s0, float2(_372, _373), 0.0f).x), 40.0f, 1.0f), 0.0f), max(1.0f - dp4_f32(float4(abs(_367.x - _379.x), abs(_367.y - _379.y), abs(_367.z - _379.z), abs(_367.w - _379.w)), 10.0f.xxxx), 0.0f));
    float4 _409 = t0.SampleLevel(s0, float2(TEXCOORD.x - cb1_m45.x, TEXCOORD.y), 0.0f);
    float _410 = _409.x;
    float _411 = _409.y;
    float _412 = _409.z;
    float4 _417 = t0.SampleLevel(s0, float2(cb1_m45.x + TEXCOORD.x, TEXCOORD.y), 0.0f);
    float _418 = _417.x;
    float _419 = _417.y;
    float _420 = _417.z;
    float4 _423 = t0.SampleLevel(s0, float2(TEXCOORD.x, cb1_m45.y + TEXCOORD.y), 0.0f);
    float _424 = _423.x;
    float _425 = _423.y;
    float _426 = _423.z;
    float4 _430 = t0.SampleLevel(s0, float2(TEXCOORD.x, TEXCOORD.y - cb1_m45.y), 0.0f);
    float _431 = _430.x;
    float _432 = _430.y;
    float _433 = _430.z;
    float _443 = min(_309, min(_410, min(_418, min(_424, _431))));
    float _444 = min(_310, min(_411, min(_419, min(_425, _432))));
    float _445 = min(_311, min(_412, min(_420, min(_426, _433))));
    float _455 = max(_309, max(_410, max(max(_424, _431), _418)));
    float _456 = max(_310, max(_411, max(max(_425, _432), _419)));
    float _457 = max(_311, max(_412, max(max(_426, _433), _420)));
    float _470 = min(min(max(_455, _443), max(_322, _455)), max(_322, _443));
    float _471 = min(min(max(_456, _444), max(_323, _456)), max(_323, _444));
    float _472 = min(min(max(_457, _445), max(_324, _457)), max(_324, _445));
    float2 _479 = float2(_263, _264);
    float2 _481 = float2(_296, _297);
    float2 _492 = float2(_263 - _296, _264 - _297);
    float _500 = clamp(mad(-asfloat((asint(dp2_f32(_492, _492)) >> int(1u)) + 532487669), 0.25f, 1.0f), 0.0f, 1.0f);
    float _503 = min(clamp(40.0f - asfloat((asint(max(dp2_f32(_481, _481), dp2_f32(_479, _479))) >> int(1u)) + 532487669), 0.0f, 1.0f), _500 * _500) * 0.5f;
    float _507 = mad(_503, mad(_406, _322 - _470, _470) - _309, _309);
    float _508 = mad(_503, mad(_406, _323 - _471, _471) - _310, _310);
    float _509 = mad(_503, mad(_406, _324 - _472, _472) - _311, _311);
    float4 _518 = t14.SampleLevel(s0, _271, 0.0f);
    float _538 = dp3_f32(float3(asfloat((asint(_518.x * 3.0517578125e-05f) >> int(1u)) + 532487669), asfloat((asint(_518.y * 3.0517578125e-05f) >> int(1u)) + 532487669), asfloat((asint(_518.z * 3.0517578125e-05f) >> int(1u)) + 532487669)), float3(0.2125999927520751953125f, 0.715200006961822509765625f, 0.072200000286102294921875f));
    float _545 = clamp(mad(max(abs(_538 - dp3_f32(float3(asfloat((asint(_322 * 3.0517578125e-05f) >> int(1u)) + 532487669), asfloat((asint(_323 * 3.0517578125e-05f) >> int(1u)) + 532487669), asfloat((asint(_324 * 3.0517578125e-05f) >> int(1u)) + 532487669)), float3(0.2125999927520751953125f, 0.715200006961822509765625f, 0.072200000286102294921875f))), abs(_538 - _341)), 6.666666507720947265625f, -0.3333333432674407958984375f), 0.0f, 1.0f);
    float2 _546 = float2(_265 * cb1_m44.x, _266 * cb1_m44.y);
    if (min(clamp(40.0f - asfloat((asint(dp2_f32(_546, _546)) >> int(1u)) + 532487669), 0.0f, 1.0f), _545) > 0.0f)
    {
        float _566 = floor(mad(cb1_m44.x, _268, -0.5f));
        float _567 = floor(mad(cb1_m44.y, _269, -0.5f));
        float _568 = _566 + 0.5f;
        float _569 = _567 + 0.5f;
        float _574 = mad(cb1_m44.x, _268, -_568);
        float _575 = mad(cb1_m44.y, _269, -_569);
        float _576 = _574 * _574;
        float _577 = _575 * _575;
        float _584 = -_576;
        float _585 = -_577;
        float _586 = mad(_584, _574, mad(_576, 2.0f, -_574));
        float _587 = mad(_585, _575, mad(_577, 2.0f, -_575));
        float _596 = mad(_584, _574, mad(_574, _574, _574));
        float _597 = mad(_585, _575, mad(_575, _575, _575));
        float _598 = mad(_576, _574, _584);
        float _599 = mad(_577, _575, _585);
        float _602 = (mad(_576, _574, -(_576 + _576)) + 1.0f) + _596;
        float _603 = (mad(_577, _575, -(_577 + _577)) + 1.0f) + _597;
        float _608 = (_566 + 2.5f) * cb1_m45.x;
        float _609 = (_567 + 2.5f) * cb1_m45.y;
        float _610 = (_566 - 0.5f) * cb1_m45.x;
        float _611 = (_569 + (_597 / _603)) * cb1_m45.y;
        float _612 = (_568 + (_596 / _602)) * cb1_m45.x;
        float _613 = (_567 - 0.5f) * cb1_m45.y;
        float4 _616 = t14.SampleLevel(s0, float2(_610, _613), 0.0f);
        float4 _625 = t14.SampleLevel(s0, float2(_612, _613), 0.0f);
        float4 _640 = t14.SampleLevel(s0, float2(_608, _613), 0.0f);
        float4 _652 = t14.SampleLevel(s0, float2(_610, _611), 0.0f);
        float4 _664 = t14.SampleLevel(s0, float2(_612, _611), 0.0f);
        float4 _676 = t14.SampleLevel(s0, float2(_608, _611), 0.0f);
        float4 _688 = t14.SampleLevel(s0, float2(_610, _609), 0.0f);
        float4 _700 = t14.SampleLevel(s0, float2(_612, _609), 0.0f);
        float4 _712 = t14.SampleLevel(s0, float2(_608, _609), 0.0f);
        uint _725;
        _725 = u6.IncrementCounter();
        u6[_725] = uint2(spvBitfieldInsert(f32_to_f16(float2(mad(_598 * _712.z, _599, mad(_602 * _700.z, _599, mad(_586 * _688.z, _599, mad(_598 * _676.z, _603, mad(_602 * _664.z, _603, mad(_586 * _652.z, _603, mad(_598 * _640.z, _587, mad(_586 * _616.z, _587, _587 * (_602 * _625.z))))))))), 0.0f)) << 17u, spvBitfieldUExtract(f32_to_f16(float2(mad(_598 * _712.x, _599, mad(_602 * _700.x, _599, mad(_586 * _688.x, _599, mad(_598 * _676.x, _603, mad(_602 * _664.x, _603, mad(_586 * _652.x, _603, mad(_598 * _640.x, _587, mad(_586 * _616.x, _587, _587 * (_602 * _625.x))))))))), 0.0f)), 4u, 11u) + ((f32_to_f16(float2(mad(_598 * _712.y, _599, mad(_602 * _700.y, _599, mad(_586 * _688.y, _599, mad(_598 * _676.y, _603, mad(_602 * _664.y, _603, mad(_586 * _652.y, _603, mad(_598 * _640.y, _587, mad(_586 * _616.y, _587, _587 * (_602 * _625.y))))))))), 0.0f)) << 7u) & 4192256u), 0u, 22u), uint(cvt_f32_i32(gl_FragCoord.x) | ((cvt_f32_i32(gl_FragCoord.y) << int(12u)) | int(cvt_f32_u32(_545 * 255.0f) << 24u))));
    }
    SV_TARGET.x = _507;
    SV_TARGET.y = _508;
    SV_TARGET.z = _509;
    SV_TARGET2.x = _507;
    SV_TARGET2.y = _508;
    SV_TARGET2.z = _509;
    SV_TARGET1 = _341;
}

SPIRV_Cross_Output main(SPIRV_Cross_Input stage_input)
{
    gl_FragCoord = stage_input.gl_FragCoord;
    gl_FragCoord.w = 1.0 / gl_FragCoord.w;
    TEXCOORD = stage_input.TEXCOORD;
    frag_main();
    SPIRV_Cross_Output stage_output;
    stage_output.SV_TARGET = SV_TARGET;
    stage_output.SV_TARGET1 = SV_TARGET1;
    stage_output.SV_TARGET2 = SV_TARGET2;
    return stage_output;
}
#else
#include "./Includes/Common.hlsl"
#include "./Includes/TAAResolve.hlsl"

cbuffer PostFxCBuffer : register(b8)
{
  float2 jitterCurrent : packoffset(c0);
  float2 jitterHistory : packoffset(c0.z);
}

cbuffer PerSceneConsts : register(b1)
{
  float4 renderTargetSize : packoffset(c44);
}

SamplerState bilinearSampler : register(s0);
Texture2D<float4> colorTex : register(t0);
Texture2D<float4> historyTex : register(t6);
Texture2D<float4> lumaHistoryTex1 : register(t7);
Texture2D<float4> lumaHistoryTex2 : register(t9);
Texture2D<float4> lumaHistoryTex3 : register(t10);
Texture2D<float4> velocityTex0 : register(t11);
Texture2D<float4> velocityTex1 : register(t12);
Texture2D<float4> filmicHistoryTex : register(t14);
Texture2D<float4> depthTex : register(t15);
RWStructuredBuffer<uint2> filmicWorkQueueRWBuffer : register(u6);

void main(
  float4 v0 : SV_POSITION0,
  float2 v1 : TEXCOORD0,
  out float3 o0 : SV_TARGET0,
  out float o1 : SV_TARGET1,
  out float3 o2 : SV_TARGET2)
{
  TAAResult r = TAA_Resolve(colorTex, historyTex, lumaHistoryTex1, lumaHistoryTex2, lumaHistoryTex3, velocityTex0, velocityTex1, depthTex, bilinearSampler,
    v1.xy, jitterCurrent, jitterHistory, renderTargetSize.xy, renderTargetSize.zw, true);
  TAA_FilmicWorkQueueAppend(filmicHistoryTex, filmicWorkQueueRWBuffer, bilinearSampler, v0.xy, v1.xy, r.reprojUV, r.velocity, r.lumaCurrent, r.lumaHistory, renderTargetSize.xy, renderTargetSize.zw);
  o0 = r.color;
  o2 = r.color;
  o1 = r.lumaCurrent;
}
#endif
