cbuffer cb0_buf : register(b0)
{
    uint2 cb0_m0 : packoffset(c0);
    uint2 cb0_m1 : packoffset(c0.z);
};

cbuffer cb1_buf : register(b1)
{
    uint4 cb1_m[55] : packoffset(c0);
};

cbuffer cb2_buf : register(b2)
{
    uint4 cb2_m[42] : packoffset(c0);
};

cbuffer cb4_buf : register(b4)
{
    uint4 cb4_m0 : packoffset(c0);
    float4 cb4_m1 : packoffset(c1);
    float4 cb4_m2 : packoffset(c2);
    uint4 cb4_m3 : packoffset(c3);
    uint4 cb4_m4 : packoffset(c4);
    float4 cb4_m5 : packoffset(c5);
    float4 cb4_m6 : packoffset(c6);
    float4 cb4_m7 : packoffset(c7);
    uint4 cb4_m8 : packoffset(c8);
    uint4 cb4_m9 : packoffset(c9);
    float4 cb4_m10 : packoffset(c10);
    float4 cb4_m11 : packoffset(c11);
};

SamplerState s0 : register(s0);
SamplerState s2 : register(s2);
SamplerState s3 : register(s3);
SamplerState s7 : register(s7);
SamplerState s9 : register(s9);
SamplerState s10 : register(s10);
SamplerState s12 : register(s12);
Texture2D<float4> t0 : register(t0);
Texture2D<float4> t2 : register(t2);
Texture2D<float4> t3 : register(t3);
TextureCube<float4> t9 : register(t9);
TextureCube<float4> t10 : register(t10);
TextureCube<float4> t11 : register(t11);
TextureCube<float4> t12 : register(t12);
TextureCube<float4> t13 : register(t13);
Texture2D<float4> t16 : register(t16);
Texture2D<float4> t19 : register(t19);

static float4 gl_FragCoord;
static float3 NORMAL;
static float3 TANGENT;
static float3 BINORMAL;
static float4 TEXCOORD;
static float4 TEXCOORD1;
static float4 TEXCOORD2;
static float4 COLOR;
static float4 COLOR1;
static float4 SV_Target;

struct SPIRV_Cross_Input
{
    float4 v0 : SV_POSITION0;
    float3 NORMAL : NORMAL0;
    float3 TANGENT : TANGENT0;
    float3 BINORMAL : BINORMAL0;
    float4 TEXCOORD : TEXCOORD0;
    float4 TEXCOORD1 : TEXCOORD1;
    float4 TEXCOORD2 : TEXCOORD2;
    float4 COLOR : COLOR0;
    float4 COLOR1 : COLOR1;
    float4 gl_FragCoord : SV_Position;
};

struct SPIRV_Cross_Output
{
    float4 SV_Target : SV_Target0;
};

#include "./Includes/Common.hlsl"

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
    precise float _157 = a.x * b.x;
    return mad(a.z, b.z, mad(a.y, b.y, _157));
}

void frag_main()
{
    float2 _176 = float2(TEXCOORD.x, TEXCOORD.y);
    float4 _179 = t0.Sample(s0, _176);
    float _183 = _179.w;
    float _188 = asfloat(cb2_m[39u].z);
#ifndef SKIN_NO_ALPHA
    if (_183 < min(_188, 0.5f))
    {
        discard;
    }
#endif
    float _199 = (_188 < 0.5f) ? max(_183, asfloat(cb2_m[39u].w)) : 1.0f;
    float _275;
    float _276;
    float _277;
    if (spvBitfieldUExtract(cb0_m1.y, 8u, 1u) == 1u)
    {
        float4 _215 = t2.Sample(s2, _176);
        float _219 = mad(_215.y, 2.0f, -1.0f);
        float _224 = ((_219 * _219) * _219) * 2.0f;
        float _225 = _224 + (mad(_215.x, 2.0f, -1.0f) * 1.5f);
        float _226 = _224 + (_219 * 1.5f);
        float _254 = ((BINORMAL.x * _226) + (_225 * TANGENT.x)) + NORMAL.x;
        float _255 = NORMAL.y + ((_225 * TANGENT.y) + (BINORMAL.y * _226));
        float _256 = NORMAL.z + ((_225 * TANGENT.z) + (BINORMAL.z * _226));
        float3 _257 = float3(_254, _255, _256);
        float _259 = rsqrt(dp3_f32(_257, _257));
        _275 = _259 * _256;
        _276 = _259 * _255;
        _277 = _254 * _259;
    }
    else
    {
        float3 _269 = float3(NORMAL.x, NORMAL.y, NORMAL.z);
        float _271 = rsqrt(dp3_f32(_269, _269));
        _275 = NORMAL.z * _271;
        _276 = NORMAL.y * _271;
        _277 = NORMAL.x * _271;
    }
    float3 _284 = float3(TEXCOORD1.x, TEXCOORD1.y, TEXCOORD1.z);
    float _286 = rsqrt(dp3_f32(_284, _284));
    float _287 = TEXCOORD1.x * _286;
    float _288 = TEXCOORD1.y * _286;
    float _289 = TEXCOORD1.z * _286;
    float3 _300 = float3(asfloat(cb1_m[42u].x), asfloat(cb1_m[42u].y), asfloat(cb1_m[42u].z));
    float3 _301 = float3(_277, _276, _275);
    float _302 = dp3_f32(_300, _301);
    float3 _311 = float3(asfloat(cb1_m[43u].x), asfloat(cb1_m[43u].y), asfloat(cb1_m[43u].z));
    float _312 = dp3_f32(_311, _301);
    float3 _321 = float3(asfloat(cb1_m[44u].x), asfloat(cb1_m[44u].y), asfloat(cb1_m[44u].z));
    float _322 = dp3_f32(_321, _301);
    float3 _323 = float3(_287, _288, _289);
    float _324 = dp3_f32(_300, _323);
    float _325 = dp3_f32(_311, _323);
    float _326 = dp3_f32(_321, _323);
    bool _330 = (cb0_m1.x & 1u) == 1u;
    float _373;
    if (spvBitfieldUExtract(cb0_m1.x, 9u, 1u) != 0u)
    {
        float _369 = min(dp3_f32(float3(asfloat(cb1_m[26u].x), asfloat(cb1_m[26u].y), asfloat(cb1_m[26u].z)), _301) + 1.0f, 1.0f);
        float _370 = _369 * _369;
        _373 = min(min(exp2(((t19.Sample(s7, float2(TEXCOORD2.x, TEXCOORD2.y)).x - TEXCOORD2.z) * asfloat(cb1_m[45u].x)) * asfloat(cb2_m[30u].w)), 1.0f), _370 * _370);
    }
    else
    {
        _373 = 1.0f;
    }
    float4 _377 = t3.Sample(s3, _176);
    float _378 = _377.w;
    float4 _395 = t16.Sample(s12, float2(gl_FragCoord.x * asfloat(cb1_m[54u].x), gl_FragCoord.y * asfloat(cb1_m[54u].y)));
    float _396 = _395.x;
    float _397 = _395.y;
    float _398 = _395.z;
    float _709;
    float _710;
    float _711;
    if (_330)
    {
        float _402 = clamp(_396, 0.0f, 1.0f);
        float _403 = clamp(_397, 0.0f, 1.0f);
        float _404 = clamp(_398, 0.0f, 1.0f);
        float _408 = mad(_373, 0.800000011920928955078125f, 0.20000000298023223876953125f);
        float _488;
        float _489;
        float _490;
        if (cb4_m5.x > 0.0f)
        {
            float3 _428 = float3(_302, _312, _322);
            float4 _431 = t9.SampleLevel(s9, _428, 0.0f);
            float4 _436 = t9.SampleLevel(s9, _428, 1.0f);
            float _437 = _436.x;
            float _438 = _436.y;
            float _439 = _436.z;
            float _443 = mad(_431.x - _437, _373, _437);
            float _444 = mad(_431.y - _438, _373, _438);
            float _445 = mad(_431.z - _439, _373, _439);
            bool _448 = cb4_m6.w > 0.0f;
            float3 _449 = float3(_443, _444, _445);
            float _454 = sqrt(dp3_f32(_449, _449)) / cb4_m7.z;
            float _467 = (_454 < cb4_m7.w) ? cb4_m7.y : ((_454 > 1.0f) ? 1.0f : mad((_454 - cb4_m7.w) / (1.0f - cb4_m7.w), 1.0f - cb4_m7.y, cb4_m7.y));
            _488 = mad((_448 ? mad(mad(cb4_m7.x, _467, -_445), cb4_m6.w, _445) : _445) - 1.0f, cb4_m5.x, 1.0f);
            _489 = mad((_448 ? mad(mad(cb4_m7.x, _467, -_444), cb4_m6.w, _444) : _444) - 1.0f, cb4_m5.x, 1.0f);
            _490 = mad((_448 ? mad(mad(cb4_m7.x, _467, -_443), cb4_m6.w, _443) : _443) - 1.0f, cb4_m5.x, 1.0f);
        }
        else
        {
            _488 = 1.0f;
            _489 = 1.0f;
            _490 = 1.0f;
        }
        float _522 = mad((_408 * mad(_402, -0.89999997615814208984375f, 1.03999996185302734375f)) + (_402 * 0.89999997615814208984375f), mad(asfloat(cb1_m[14u].x) * _490, cb4_m1.w, COLOR.w), asfloat(cb1_m[15u].x)) * cb4_m1.y;
        float _523 = cb4_m1.y * mad(mad(asfloat(cb1_m[14u].y) * _489, cb4_m1.w, COLOR.w), (_408 * mad(_403, -0.769999980926513671875f, 1.03999996185302734375f)) + (_403 * 0.769999980926513671875f), asfloat(cb1_m[15u].y));
        float _524 = cb4_m1.y * mad(mad(asfloat(cb1_m[14u].z) * _488, cb4_m1.w, COLOR.w), (_408 * mad(_404, -0.87999999523162841796875f, 1.03999996185302734375f)) + (_404 * 0.87999999523162841796875f), asfloat(cb1_m[15u].z));
        bool _539 = ((TEXCOORD.y < cb4_m11.w) && (TEXCOORD.y > cb4_m11.z)) && ((TEXCOORD.x > cb4_m11.x) && (TEXCOORD.x < cb4_m11.y));
        float _549 = dp3_f32(_301, float3(asfloat(cb1_m[26u].x), asfloat(cb1_m[26u].y), asfloat(cb1_m[26u].z)));
        float _568 = 1.0f - cb4_m10.y;
        float _583 = mad(-((1.0f - (abs(mad(cb4_m11.y + cb4_m11.x, 0.5f, -TEXCOORD.x)) / ((cb4_m11.y - cb4_m11.x) * 0.5f))) * ((_549 > cb4_m10.x) ? 0.0f : ((_549 > (cb4_m10.x - cb4_m10.z)) ? (_568 * ((cb4_m10.x - _549) / cb4_m10.z)) : _568))), 1.0f - (abs(mad(cb4_m11.w + cb4_m11.z, 0.5f, -TEXCOORD.y)) / ((cb4_m11.w - cb4_m11.z) * 0.5f)), 1.0f);
        _709 = _539 ? (_583 * _524) : _524;
        _710 = _539 ? (_583 * _523) : _523;
        _711 = _539 ? (_522 * _583) : _522;
    }
    else
    {
        float3 _590 = float3(_302, _312, _322);
        float4 _600 = t9.SampleLevel(s9, _590, 0.0f);
        float4 _605 = t9.SampleLevel(s9, _590, 1.0f);
        float _606 = _605.x;
        float _607 = _605.y;
        float _608 = _605.z;
        bool _642 = spvBitfieldUExtract(cb0_m0.y, 12u, 1u) == 1u;
        float _662 = clamp((mad(dp3_f32(_301, float3(asfloat(cb1_m[33u].x), asfloat(cb1_m[33u].y), asfloat(cb1_m[33u].z))), 0.5f, 0.5f) - asfloat(cb1_m[36u].x)) * asfloat(cb1_m[36u].y), 0.0f, 1.0f);
        float _668 = asfloat(cb1_m[34u].x);
        float _669 = asfloat(cb1_m[34u].y);
        float _670 = asfloat(cb1_m[34u].z);
        float _687 = asfloat(cb1_m[36u].z);
        float _695 = float(_378 > 0.9900000095367431640625f);
        float _696 = mad(_642 ? (mad(_662, asfloat(cb1_m[35u].x) - _668, _668) * _687) : 0.0f, _695, mad(mad(_600.x - _606, _373, _606), asfloat(cb1_m[14u].x), COLOR.w) + asfloat(cb1_m[15u].x));
        float _697 = mad(_642 ? (_687 * mad(_662, asfloat(cb1_m[35u].y) - _669, _669)) : 0.0f, _695, asfloat(cb1_m[15u].y) + mad(asfloat(cb1_m[14u].y), mad(_373, _600.y - _607, _607), COLOR.w));
        float _698 = mad(_642 ? (_687 * mad(_662, asfloat(cb1_m[35u].z) - _670, _670)) : 0.0f, _695, asfloat(cb1_m[15u].z) + mad(asfloat(cb1_m[14u].z), mad(_373, _600.z - _608, _608), COLOR.w));
        float _702 = mad(1.0f / rsqrt(clamp(dp3_f32(_590, float3(_324, _325, _326)), 0.0f, 1.0f)), 0.75f, 0.25f) * asfloat(cb2_m[41u].x);
        _709 = mad(_702, _398 - _698, _698);
        _710 = mad(_702, _397 - _697, _697);
        _711 = mad(_702, _396 - _696, _696);
    }
    if ((_188 >= _199) && (_199 != 1.0f))
    {
        discard;
    }
    float _736 = dp3_f32(_323, _301);
    float _737 = _736 + _736;
    float3 _744 = float3((_737 * _277) - _287, (_737 * _276) - _288, (_737 * _275) - _289);
    float _751 = mad(_302 - _324, 1.25f, _324);
    float _752 = mad(_312 - _325, 1.25f, _325);
    float _753 = mad(_322 - _326, 1.25f, _326);
    float3 _754 = float3(_751, _752, _753);
    float _756 = rsqrt(dp3_f32(_754, _754));
    float _764 = clamp(1.0f - dp3_f32(float3(_751 * _756, _756 * _752, _756 * _753), float3(_324, _325, _326)), 0.0f, 1.0f);
    float _765 = _764 * _764;
    float _767 = _764 * (_765 * _765);
    float _771 = _378 * _373;
    float _777 = asfloat(cb2_m[34u].w);
    float _778 = mad(_777, 15.0f, 0.100000001490116119384765625f);
    float3 _781 = float3(dp3_f32(_300, _744), dp3_f32(_311, _744), dp3_f32(_321, _744));
    float4 _783 = t10.SampleLevel(s10, _781, 0.0f);
    float4 _789 = t11.SampleLevel(s10, _781, 1.0f);
    float _790 = _789.x;
    float _791 = _789.y;
    float _792 = _789.z;
    float4 _801 = t12.SampleLevel(s10, _781, 0.0f);
    float4 _807 = t13.SampleLevel(s10, _781, 1.0f);
    float _808 = _807.x;
    float _809 = _807.y;
    float _810 = _807.z;
    float _814 = mad(_778, _801.x - _808, _808);
    float _815 = mad(_778, _801.y - _809, _809);
    float _816 = mad(_778, _801.z - _810, _810);
    float _834 = mad(_771, 0.699999988079071044921875f, 0.300000011920928955078125f);
    float _838 = _777 + (_330 ? mad(_767, 0.300000011920928955078125f, 0.032999999821186065673828125f) : mad(_767, 0.20000000298023223876953125f, 0.02199999988079071044921875f));
    float _855 = mad(_838, asfloat(cb2_m[36u].x) * GS.SkinSpecular, asfloat(cb2_m[37u].x));
    float _856 = mad(_838, asfloat(cb2_m[36u].y) * GS.SkinSpecular, asfloat(cb2_m[37u].y));
    float _857 = mad(_838, asfloat(cb2_m[36u].z) * GS.SkinSpecular, asfloat(cb2_m[37u].z));
    float _873 = ((mad(_179.x, asfloat(cb2_m[34u].x), asfloat(cb2_m[35u].x)) * _711) * 0.980000019073486328125f) + (((mad(_771, mad(_778, _783.x - _790, _790) - _814, _814) * asfloat(cb1_m[16u].x)) * _834) * (_330 ? (cb4_m2.x * _855) : _855));
    float _874 = ((mad(_179.y, asfloat(cb2_m[34u].y), asfloat(cb2_m[35u].y)) * _710) * 0.980000019073486328125f) + (((mad(_771, mad(_778, _783.y - _791, _791) - _815, _815) * asfloat(cb1_m[16u].y)) * _834) * (_330 ? (cb4_m2.x * _856) : _856));
    float _875 = ((mad(_179.z, asfloat(cb2_m[34u].z), asfloat(cb2_m[35u].z)) * _709) * 0.980000019073486328125f) + (((mad(_771, mad(_778, _783.z - _792, _792) - _816, _816) * asfloat(cb1_m[16u].z)) * _834) * (_330 ? (cb4_m2.x * _857) : _857));
    bool _879 = spvBitfieldUExtract(cb0_m0.x, 10u, 1u) == 1u;
    float _881 = dp3_f32(float3(_873, _874, _875), float3(0.29890000820159912109375f, 0.586600005626678466796875f, 0.11450000107288360595703125f));
    float _887 = asfloat(cb1_m[31u].x);
    float _888 = asfloat(cb1_m[31u].y);
    float _889 = asfloat(cb1_m[31u].z);
    float _909 = asfloat(cb1_m[32u].w);
    SV_Target.x = _879 ? max(mad(mad(_881, asfloat(cb1_m[32u].x) - _887, _887) - _873, _909, _873), 0.0f) : mad(COLOR1.x - _873, TEXCOORD2.w, _873);
    SV_Target.y = _879 ? max(mad(mad(asfloat(cb1_m[32u].y) - _888, _881, _888) - _874, _909, _874), 0.0f) : mad(COLOR1.y - _874, TEXCOORD2.w, _874);
    SV_Target.z = _879 ? max(mad(mad(asfloat(cb1_m[32u].z) - _889, _881, _889) - _875, _909, _875), 0.0f) : mad(COLOR1.z - _875, TEXCOORD2.w, _875);
    SV_Target.w = _199;
}

SPIRV_Cross_Output main(SPIRV_Cross_Input stage_input)
{
    gl_FragCoord = stage_input.gl_FragCoord;
    gl_FragCoord.w = 1.0 / gl_FragCoord.w;
    NORMAL = stage_input.NORMAL;
    TANGENT = stage_input.TANGENT;
    BINORMAL = stage_input.BINORMAL;
    TEXCOORD = stage_input.TEXCOORD;
    TEXCOORD1 = stage_input.TEXCOORD1;
    TEXCOORD2 = stage_input.TEXCOORD2;
    COLOR = stage_input.COLOR;
    COLOR1 = stage_input.COLOR1;
    frag_main();
    SPIRV_Cross_Output stage_output;
    stage_output.SV_Target = SV_Target;
    return stage_output;
}
