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
    precise float _168 = a.x * b.x;
    return mad(a.z, b.z, mad(a.y, b.y, _168));
}

float dp4_f32(float4 a, float4 b)
{
    precise float _151 = a.x * b.x;
    return mad(a.w, b.w, mad(a.z, b.z, mad(a.y, b.y, _151)));
}

float dp2_f32(float2 a, float2 b)
{
    precise float _140 = a.x * b.x;
    return mad(a.y, b.y, _140);
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
    float4 _202 = t14.SampleLevel(s0, float2(mad(cb1_m45.x, -2.0f, TEXCOORD.x), mad(cb1_m45.y, -2.0f, TEXCOORD.y)), 0.0f);
    float _203 = _202.x;
    float _206 = (max(_203, t14.SampleLevel(s0, float2(mad(cb1_m45.x, 2.0f, TEXCOORD.x), mad(cb1_m45.y, 2.0f, TEXCOORD.y)), 0.0f).x) == _203) ? (-2.0f) : 2.0f;
    float4 _212 = t10.SampleLevel(s0, float2(mad(cb1_m45.x, _206, TEXCOORD.x), mad(cb1_m45.y, _206, TEXCOORD.y)), 0.0f);
    float _213 = _212.x;
    float _214 = _212.y;
    float _215 = abs(_213);
    float _216 = abs(_214);
    float _217 = _215 - 0.5f;
    float _218 = _216 - 0.5f;
    float _229 = mad(clamp(_217 + _217, 0.0f, 1.0f), 30.0f, min(_215 + _215, 1.0f) * 10.0f);
    float _230 = mad(clamp(_218 + _218, 0.0f, 1.0f), 30.0f, min(_216 + _216, 1.0f) * 10.0f);
    float _235 = (_213 >= 0.0f) ? _229 : (-_229);
    float _236 = (_214 >= 0.0f) ? _230 : (-_230);
    float _237 = _235 * cb1_m45.x;
    float _238 = _236 * cb1_m45.y;
    float _239 = -cb1_m45.x;
    float _240 = -cb1_m45.y;
    float _241 = mad(_239, _235, TEXCOORD.x);
    float _242 = mad(_240, _236, TEXCOORD.y);
    float2 _244 = float2(_241, _242);
    float4 _246 = t11.SampleLevel(s0, _244, 0.0f);
    float _247 = _246.x;
    float _248 = _246.y;
    float _249 = abs(_247);
    float _250 = abs(_248);
    float _251 = _249 - 0.5f;
    float _252 = _250 - 0.5f;
    float _263 = mad(clamp(_251 + _251, 0.0f, 1.0f), 30.0f, min(_249 + _249, 1.0f) * 10.0f);
    float _264 = mad(clamp(_252 + _252, 0.0f, 1.0f), 30.0f, min(_250 + _250, 1.0f) * 10.0f);
    float _269 = (_247 >= 0.0f) ? _263 : (-_263);
    float _270 = (_248 >= 0.0f) ? _264 : (-_264);
    float4 _281 = t0.SampleLevel(s0, float2(TEXCOORD.x + cb8_m0.x, TEXCOORD.y + cb8_m0.y), 0.0f);
    float _282 = _281.x;
    float _283 = _281.y;
    float _284 = _281.z;
    float4 _294 = t6.SampleLevel(s0, float2(_241 + cb8_m1.x, _242 + cb8_m1.y), 0.0f);
    float _295 = _294.x;
    float _296 = _294.y;
    float _297 = _294.z;
    float _314 = dp3_f32(float3(asfloat((asint(_282 * 3.0517578125e-05f) >> int(1u)) + 532487669), asfloat((asint(_283 * 3.0517578125e-05f) >> int(1u)) + 532487669), asfloat((asint(_284 * 3.0517578125e-05f) >> int(1u)) + 532487669)), float3(0.2125999927520751953125f, 0.715200006961822509765625f, 0.072200000286102294921875f));
    float _331 = dp3_f32(float3(asfloat((asint(_295 * 3.0517578125e-05f) >> int(1u)) + 532487669), asfloat((asint(_296 * 3.0517578125e-05f) >> int(1u)) + 532487669), asfloat((asint(_297 * 3.0517578125e-05f) >> int(1u)) + 532487669)), float3(0.2125999927520751953125f, 0.715200006961822509765625f, 0.072200000286102294921875f));
    float _374;
    if (abs(_314 - _331) > 0.02500000037252902984619140625f)
    {
        float4 _345 = t7.GatherRed(s0, _244);
        float4 _357 = t9.GatherRed(s0, float2(mad(_239, _269, _241) - mad(mad(cb1_m45.x, _269, -_237), 2.0f, _237), mad(_240, _270, _242) - mad(mad(cb1_m45.y, _270, -_238), 2.0f, _238)));
        _374 = max(1.0f - dp4_f32(float4(abs(_345.x - _357.x), abs(_345.y - _357.y), abs(_345.z - _357.z), abs(_345.w - _357.w)), 10.0f.xxxx), 0.0f);
    }
    else
    {
        _374 = 1.0f;
    }
    float2 _375 = float2(_235, _236);
    float2 _377 = float2(_269, _270);
    float2 _388 = float2(_235 - _269, _236 - _270);
    float _396 = clamp(mad(-asfloat((asint(dp2_f32(_388, _388)) >> int(1u)) + 532487669), 0.25f, 1.0f), 0.0f, 1.0f);
    float _400 = min(min(clamp(40.0f - asfloat((asint(max(dp2_f32(_375, _375), dp2_f32(_377, _377))) >> int(1u)) + 532487669), 0.0f, 1.0f), _396 * _396), _374) * 0.5f;
    float _404 = mad(_400, _295 - _282, _282);
    float _405 = mad(_400, _296 - _283, _283);
    float _406 = mad(_400, _297 - _284, _284);
    float2 _409 = float2(mad(TEXCOORD.x, 1.5f, -0.75f), mad(TEXCOORD.y, 1.10000002384185791015625f, -0.49500000476837158203125f));
    float4 _425 = t12.SampleLevel(s0, _244, 0.0f);
    float _445 = dp3_f32(float3(asfloat((asint(_425.x * 3.0517578125e-05f) >> int(1u)) + 532487669), asfloat((asint(_425.y * 3.0517578125e-05f) >> int(1u)) + 532487669), asfloat((asint(_425.z * 3.0517578125e-05f) >> int(1u)) + 532487669)), float3(0.2125999927520751953125f, 0.715200006961822509765625f, 0.072200000286102294921875f));
    float _453 = clamp(mad(clamp(1.0f - asfloat((asint(dp2_f32(_409, _409)) >> int(1u)) + 532487669), 0.0f, 1.0f) * 6.666666507720947265625f, max(abs(_445 - _331), abs(_445 - _314)), -0.3333333432674407958984375f), 0.0f, 1.0f);
    float2 _454 = float2(_237 * cb1_m44.x, _238 * cb1_m44.y);
    if (min(clamp(40.0f - asfloat((asint(dp2_f32(_454, _454)) >> int(1u)) + 532487669), 0.0f, 1.0f), _453) > 0.0f)
    {
        float _474 = floor(mad(cb1_m44.x, _241, -0.5f));
        float _475 = floor(mad(cb1_m44.y, _242, -0.5f));
        float _476 = _474 + 0.5f;
        float _477 = _475 + 0.5f;
        float _482 = mad(cb1_m44.x, _241, -_476);
        float _483 = mad(cb1_m44.y, _242, -_477);
        float _484 = _482 * _482;
        float _485 = _483 * _483;
        float _492 = -_484;
        float _493 = -_485;
        float _494 = mad(_492, _482, mad(_484, 2.0f, -_482));
        float _495 = mad(_493, _483, mad(_485, 2.0f, -_483));
        float _504 = mad(_492, _482, mad(_482, _482, _482));
        float _505 = mad(_493, _483, mad(_483, _483, _483));
        float _506 = mad(_484, _482, _492);
        float _507 = mad(_485, _483, _493);
        float _510 = (mad(_484, _482, -(_484 + _484)) + 1.0f) + _504;
        float _511 = (mad(_485, _483, -(_485 + _485)) + 1.0f) + _505;
        float _516 = (_474 + 2.5f) * cb1_m45.x;
        float _517 = (_475 + 2.5f) * cb1_m45.y;
        float _518 = (_474 - 0.5f) * cb1_m45.x;
        float _519 = (_477 + (_505 / _511)) * cb1_m45.y;
        float _520 = (_476 + (_504 / _510)) * cb1_m45.x;
        float _521 = (_475 - 0.5f) * cb1_m45.y;
        float4 _524 = t12.SampleLevel(s0, float2(_518, _521), 0.0f);
        float4 _533 = t12.SampleLevel(s0, float2(_520, _521), 0.0f);
        float4 _548 = t12.SampleLevel(s0, float2(_516, _521), 0.0f);
        float4 _560 = t12.SampleLevel(s0, float2(_518, _519), 0.0f);
        float4 _572 = t12.SampleLevel(s0, float2(_520, _519), 0.0f);
        float4 _584 = t12.SampleLevel(s0, float2(_516, _519), 0.0f);
        float4 _596 = t12.SampleLevel(s0, float2(_518, _517), 0.0f);
        float4 _608 = t12.SampleLevel(s0, float2(_520, _517), 0.0f);
        float4 _620 = t12.SampleLevel(s0, float2(_516, _517), 0.0f);
        uint _633;
        _633 = u6.IncrementCounter();
        u6[_633] = uint2(spvBitfieldInsert(f32_to_f16(float2(mad(_506 * _620.z, _507, mad(_510 * _608.z, _507, mad(_494 * _596.z, _507, mad(_506 * _584.z, _511, mad(_510 * _572.z, _511, mad(_494 * _560.z, _511, mad(_506 * _548.z, _495, mad(_494 * _524.z, _495, _495 * (_510 * _533.z))))))))), 0.0f)) << 17u, spvBitfieldUExtract(f32_to_f16(float2(mad(_506 * _620.x, _507, mad(_510 * _608.x, _507, mad(_494 * _596.x, _507, mad(_506 * _584.x, _511, mad(_510 * _572.x, _511, mad(_494 * _560.x, _511, mad(_506 * _548.x, _495, mad(_494 * _524.x, _495, _495 * (_510 * _533.x))))))))), 0.0f)), 4u, 11u) + ((f32_to_f16(float2(mad(_506 * _620.y, _507, mad(_510 * _608.y, _507, mad(_494 * _596.y, _507, mad(_506 * _584.y, _511, mad(_510 * _572.y, _511, mad(_494 * _560.y, _511, mad(_506 * _548.y, _495, mad(_494 * _524.y, _495, _495 * (_510 * _533.y))))))))), 0.0f)) << 7u) & 4192256u), 0u, 22u), uint(cvt_f32_i32(gl_FragCoord.x) | ((cvt_f32_i32(gl_FragCoord.y) << int(12u)) | int(cvt_f32_u32(_453 * 255.0f) << 24u))));
    }
    SV_TARGET.x = _404;
    SV_TARGET.y = _405;
    SV_TARGET.z = _406;
    SV_TARGET2.x = _404;
    SV_TARGET2.y = _405;
    SV_TARGET2.z = _406;
    SV_TARGET1 = _314;
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
Texture2D<float4> lumaHistoryTex3 : register(t9);
Texture2D<float4> velocityTex0 : register(t10);
Texture2D<float4> velocityTex1 : register(t11);
Texture2D<float4> filmicHistoryTex : register(t12);
Texture2D<float4> depthTex : register(t14);
RWStructuredBuffer<uint2> filmicWorkQueueRWBuffer : register(u6);

void main(
  float4 v0 : SV_POSITION0,
  float2 v1 : TEXCOORD0,
  out float3 o0 : SV_TARGET0,
  out float o1 : SV_TARGET1,
  out float3 o2 : SV_TARGET2)
{
  TAAResult r = TAA_Resolve(colorTex, historyTex, lumaHistoryTex1, lumaHistoryTex1, lumaHistoryTex3, velocityTex0, velocityTex1, depthTex, bilinearSampler,
    v1.xy, jitterCurrent, jitterHistory, renderTargetSize.xy, renderTargetSize.zw, false);
  TAA_FilmicWorkQueueAppend(filmicHistoryTex, filmicWorkQueueRWBuffer, bilinearSampler, v0.xy, v1.xy, r.reprojUV, r.velocity, r.lumaCurrent, r.lumaHistory, renderTargetSize.xy, renderTargetSize.zw);
  o0 = r.color;
  o2 = r.color;
  o1 = r.lumaCurrent;
}
#endif
