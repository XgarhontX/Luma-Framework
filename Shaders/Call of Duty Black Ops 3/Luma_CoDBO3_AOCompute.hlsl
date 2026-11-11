#include "Includes/Common.hlsl"

#ifndef GTAO_SLICES
#define GTAO_SLICES 6
#endif
#ifndef AO_DENOISE_VARIANT
#define AO_DENOISE_VARIANT 0
#endif

cbuffer cb8_buf : register(b8)
{
    float4 cb8_m0 : packoffset(c0);
    float4 cb8_m1 : packoffset(c1);
};

cbuffer cb1_buf : register(b1)
{
    uint4 cb1_m[74] : packoffset(c0);
};

SamplerState s0 : register(s0);
Texture2D<float4> t0 : register(t0);
Texture2D<float4> t1 : register(t1);
Texture2D<float4> t2 : register(t2);
Texture2D<float4> t3 : register(t3);
Texture2D<float4> t4 : register(t4);
Texture2D<float4> t5 : register(t5);
Texture2D<float4> t7 : register(t7);
RWTexture2D<float> uOut : register(u0);

uint spvBitfieldInsert(uint Base, uint Insert, uint Offset, uint Count)
{
    uint Mask = Count == 32 ? 0xffffffff : (((1u << Count) - 1) << (Offset & 31));
    return (Base & ~Mask) | ((Insert << Offset) & Mask);
}

int cvt_f32_i32(float v)
{
    return int(v);
}

uint cvt_f32_u32(float v)
{
    return (v > 4294967040.0f) ? 4294967295u : uint(max(v, 0.0f));
}

float dp2_f32(float2 a, float2 b)
{
    precise float _104 = a.x * b.x;
    return mad(a.y, b.y, _104);
}

float dp3_f32(float3 a, float3 b)
{
    precise float _89 = a.x * b.x;
    return mad(a.z, b.z, mad(a.y, b.y, _89));
}

static float4 gl_FragCoord;
static float2 TEXCOORD;

bool SetupPixel(uint2 id)
{
    uint2 size;
    uOut.GetDimensions(size.x, size.y);
    if (any(id >= size)) return false;
    float2 inv_size = float2(asfloat(cb1_m[44u].z), asfloat(cb1_m[44u].w));
    gl_FragCoord = float4(float2(id) + 0.5, 0.0, 1.0);
    TEXCOORD = gl_FragCoord.xy * inv_size;
    return true;
}


float GTAO()
{
    int _136 = cvt_f32_i32(gl_FragCoord.x);
    int _137 = cvt_f32_i32(gl_FragCoord.y);
    uint _139 = uint(_136);
    uint _140 = uint(_137);

    float _144 = t2.Load(int3(uint2(_139, _140), 0u)).x;

    if (_144 >= 65504.0f) return 1.0f;

    float4 _154 = t1.Load(int3(uint2(uint(_136 << int(1u)), uint(_137 << int(1u))), 0u));
    uint _159 = cvt_f32_u32(mad(_154.w, 3.0f, 0.5f));
    float _162 = mad(_154.x, 2.0f, -1.0f) * 0.85000002384185791015625f;
    float _163 = mad(_154.y, 2.0f, -1.0f) * 0.85000002384185791015625f;
    float2 _164 = float2(_162, _163);
    float _165 = dp2_f32(_164, _164);
    float _168 = sqrt(2.0f - _165);
    bool _173 = (_159 & 2u) != 0u;
    bool _174 = (_159 & 1u) != 0u;
    float _175 = _173 ? (-1.0f) : 1.0f;
    float _176 = _174 ? (-1.0f) : 1.0f;
    float _178 = (_173 != _174) ? (-1.0f) : 1.0f;
    float _181 = _178 * 1.0f;
    float _184 = (_168 * _162) * 0.40824830532073974609375f;
    float _185 = (_168 * _163) * 0.707106769084930419921875f;
    float _186 = (1.0f - _165) * 0.57735025882720947265625f;
    float _196 = mad(_186, _175, ((_175 * (-1.0f)) * _185) + ((_175 * 1.0f) * _184));
    float _197 = mad(_186, _176, ((_176 * (-2.0f)) * _184) + ((_176 * 0.0f) * _185));
    float _198 = mad(_178, _186, (_181 * _184) + (_181 * _185));
    float _234 = mad(asfloat(cb1_m[6u].x), _198, (asfloat(cb1_m[5u].x) * _197) + (_196 * asfloat(cb1_m[4u].x)));
    float _235 = mad(asfloat(cb1_m[6u].y), _198, (_196 * asfloat(cb1_m[4u].y)) + (asfloat(cb1_m[5u].y) * _197));
    float _236 = mad(asfloat(cb1_m[6u].z), _198, (_196 * asfloat(cb1_m[4u].z)) + (asfloat(cb1_m[5u].z) * _197));

    float _253 = mad(float(spvBitfieldInsert(spvBitfieldInsert(0u, _139, 2u, 2u) + spvBitfieldInsert(0u, _140, 2u, 2u), _139, 0u, 2u) & 15u), 0.0625f, cb8_m0.z);
    float _260 = asfloat(cb1_m[44u].z);
    float _261 = asfloat(cb1_m[44u].w);
    float _262 = gl_FragCoord.x * _260;
    float _263 = gl_FragCoord.y * _261;
    float _266 = 100.0f / _144;
    float _273 = min(_260 * 100.0f, _266 * cb8_m0.x);
    float _274 = min(_266 * cb8_m0.y, _261 * 100.0f);
    float _279 = asfloat(cb1_m[73u].x);
    float _280 = asfloat(cb1_m[73u].y);
    float _283 = asfloat(cb1_m[73u].z);
    float _284 = asfloat(cb1_m[73u].w);
    float _289 = _144 * mad(_262, _279, -_283);
    float _290 = _144 * mad(_263, _280, -_284);
    float3 _294 = float3(-_289, -_290, -_144);
    float _296 = rsqrt(dp3_f32(_294, _294));
    float _297 = _289 * _296;
    float _298 = -_297;
    float _299 = _296 * _290;
    float _300 = -_299;
    float _301 = _144 * _296;
    float _302 = -_301;
    float _303 = _144 * 0.0024999999441206455230712890625f;
    float _304 = _236 + 1.0f;
    float _305 = frac(mad(float(uint((_136 - _137) & 3)), 0.25f, cb8_m0.w)) * 0.25f;

    const float slice_angle = 3.1415998935699462890625f / float(GTAO_SLICES);
    float _307 = 0.0f;
    [unroll]
    for (int _314 = 0; _314 < GTAO_SLICES; _314++)
    {
        float _321 = (float(_314) * slice_angle) + (_253 * slice_angle);
        float _322 = sin(_321);
        float _323 = cos(_321);

        float _328 = -1.0f;
        uint _325 = 3276275712u;
        [loop]
        for (int _334 = 0; _334 < 4; _334++)
        {
            float _340 = _305 + (float(_334) * 0.25f);
            float _341 = _340 * _340;
            float _346 = _262 + ((_273 * _341) * _323);
            float _347 = _263 + (_322 * (_274 * _341));
            float _354 = t2.SampleLevel(s0, float2(_346, _347), _341 * 5.0f).x;
            float3 _366 = float3((_354 * mad(_279, _346, -_283)) - _289, (_354 * mad(_280, _347, -_284)) - _290, _354 + mad(_303, _304, -_144));
            float _367 = dp3_f32(_366, _366);
            float _368 = rsqrt(_367);
            float _370 = dp3_f32(_366, float3(_298, _300, _302));
            float _375 = asfloat((asint(_367) >> int(1u)) + 532487669);
            float _378 = clamp(mad(_375, 0.0333333350718021392822265625f, -0.3333333432674407958984375f), 0.0f, 1.0f);
            float _385 = (_368 * _370) + (mad(clamp(mad(_354, 0.006666666828095912933349609375f, -0.3333333432674407958984375f), 0.0f, 1.0f), clamp(mad(_375, 0.006666666828095912933349609375f, -0.3333333432674407958984375f), 0.0f, 1.0f) - _378, _378) * (-2.0f));
            float _387 = dp3_f32(_366, float3(_234, _235, _236));
            bool _389 = _385 > _328;
            uint _326 = _389 ? asuint(_387) : _325;
            float _390 = max(_385, _328);
            float _329 = mad(min(clamp(mad((_389 ? _387 : asfloat(_325)) - _387, 0.100000001490116119384765625f, -1.0f), 0.0f, 1.0f), 0.367879450321197509765625f), mad(_368, _370, -_390), _390);
            _325 = _326;
            _328 = _329;
        }

        float _403 = -1.0f;
        uint _400 = 3276275712u;
        [loop]
        for (int _409 = 0; _409 < 4; _409++)
        {
            float _415 = _305 + (float(_409) * 0.25f);
            float _416 = _415 * _415;
            float _421 = _262 - (_323 * (_273 * _416));
            float _422 = _263 - (_322 * (_274 * _416));
            float _428 = t2.SampleLevel(s0, float2(_421, _422), _416 * 5.0f).x;
            float3 _440 = float3((_428 * mad(_279, _421, -_283)) - _289, (_428 * mad(_280, _422, -_284)) - _290, _428 + mad(_303, _304, -_144));
            float _441 = dp3_f32(_440, _440);
            float _442 = rsqrt(_441);
            float _444 = dp3_f32(_440, float3(_298, _300, _302));
            float _449 = asfloat((asint(_441) >> int(1u)) + 532487669);
            float _452 = clamp(mad(_449, 0.0333333350718021392822265625f, -0.3333333432674407958984375f), 0.0f, 1.0f);
            float _459 = (_442 * _444) + (mad(clamp(mad(_428, 0.006666666828095912933349609375f, -0.3333333432674407958984375f), 0.0f, 1.0f), clamp(mad(_449, 0.006666666828095912933349609375f, -0.3333333432674407958984375f), 0.0f, 1.0f) - _452, _452) * (-2.0f));
            float _461 = dp3_f32(_440, float3(_234, _235, _236));
            bool _463 = _459 > _403;
            uint _401 = _463 ? asuint(_461) : _400;
            float _464 = max(_459, _403);
            float _404 = mad(min(clamp(mad((_463 ? _461 : asfloat(_400)) - _461, 0.100000001490116119384765625f, -1.0f), 0.0f, 1.0f), 0.367879450321197509765625f), mad(_442, _444, -_464), _464);
            _400 = _401;
            _403 = _404;
        }

        float _473 = _279 * _323;
        float _474 = _280 * _322;
        float2 _475 = float2(_473, _474);
        float _477 = rsqrt(dp2_f32(_475, _475));
        float _478 = _473 * _477;
        float _479 = _477 * _474;
        float _486 = (_301 * _478) + (_299 * (-0.0f));
        float _487 = (_301 * _479) - (_297 * (-0.0f));
        float _488 = (_297 * _478) + (_299 * _479);
        float _492 = _297 * _487;
        float _495 = _299 * _486;
        float _496 = (_299 * _488) + (_301 * _487);
        float _498 = (_301 * _486) + (_297 * _488);
        float _502 = dp3_f32(float3(_234, _235, _236), float3(-_496, _498, _492 - _495));
        float3 _508 = float3(mad(_496, _502, _234), mad(-_502, _498, _235), mad(_502, _495 - _492, _236));
        float _514 = (dp3_f32(float3(_486, _487, -_488), _508) >= 0.0f) ? (-1.0f) : 1.0f;
        float _518 = clamp(rsqrt(dp3_f32(_508, _508)) * dp3_f32(_508, float3(_298, _300, _302)), 0.0f, 1.0f);
        float _525 = mad(_518, -0.15658299624919891357421875f, 1.57079994678497314453125f) * asfloat((asint(1.0f - _518) >> int(1u)) + 532487669);
        float _527 = abs(_328);
        float _528 = mad(_527, -0.15658299624919891357421875f, 1.57079994678497314453125f);
        float _533 = asfloat((asint(1.0f - _527) >> int(1u)) + 532487669);
        float _539 = abs(_403);
        float _540 = mad(_539, -0.15658299624919891357421875f, 1.57079994678497314453125f);
        float _545 = asfloat((asint(1.0f - _539) >> int(1u)) + 532487669);
        float _554 = mad(_525, _514, clamp(-mad(_525, _514, (_328 >= 0.0f) ? (_528 * _533) : mad(-_528, _533, 3.1415998935699462890625f)), -1.57079994678497314453125f, 1.57079994678497314453125f));
        float _558 = mad(_525, _514, clamp(mad(-_525, _514, (_403 >= 0.0f) ? (_540 * _545) : mad(-_540, _545, 3.1415998935699462890625f)), -1.57079994678497314453125f, 1.57079994678497314453125f));
        float _565 = _514 * asfloat((asint(mad(-_518, _518, 1.0f)) >> int(1u)) + 532487669);
        float _566 = _554 + _554;
        float _567 = _558 + _558;
        _307 += ((((mad(_567, _565, _518) - cos(mad(-_525, _514, _567))) * 0.25f) + ((mad(_566, _565, _518) - cos(mad(-_525, _514, _566))) * 0.25f)) / mad(_525 * _514, _565, _518));
    }

    float _583 = _307 * (1.0f / float(GTAO_SLICES));
    return max(_583, _583 * mad(_583, mad(_307, 0.949999988079071044921875f / float(GTAO_SLICES), -1.9500000476837158203125f), 2.0f));
}

[numthreads(8, 8, 1)]
void gtao_cs(uint3 id : SV_DispatchThreadID)
{
    if (!SetupPixel(id.xy)) return;
    uOut[id.xy] = GTAO();
}


#if AO_DENOISE_VARIANT == 0
float Denoise()
{
    float ao = 1.0f;
    float _47 = asfloat(cb1_m[44u].z);
    float _48 = asfloat(cb1_m[44u].w);
    float _54 = mad(_47, 0.5f, TEXCOORD.x);
    float _56 = mad(_48, 0.5f, TEXCOORD.y);
    float2 _59 = float2(_54, _56);
    float4 _62 = t0.GatherRed(s0, _59);
    float _67 = _62.w;
    if (_67 < 65504.0f)
    {
        float _74 = 1.0f / (_67 * 0.00999999977648258209228515625f);
        float _75 = mad(_47, -1.5f, TEXCOORD.x);
        float _76 = mad(_48, -1.5f, TEXCOORD.y);
        float2 _77 = float2(_75, _56);
        float4 _79 = t0.GatherRed(s0, _77);
        float _84 = _67 * _74;
        float _89 = (_74 * _79.x) - _84;
        float _90 = (_74 * _79.y) - _84;
        float _91 = (_74 * _79.z) - _84;
        float _92 = (_74 * _79.w) - _84;
        float _96 = (_62.x * _74) - _84;
        float _97 = (_62.y * _74) - _84;
        float _98 = (_62.z * _74) - _84;
        float _99 = _84 - _84;
        float2 _100 = float2(_54, _76);
        float4 _102 = t0.GatherRed(s0, _100);
        float _111 = (_74 * _102.x) - _84;
        float _112 = (_74 * _102.y) - _84;
        float _113 = (_74 * _102.z) - _84;
        float _114 = (_74 * _102.w) - _84;
        float2 _115 = float2(_75, _76);
        float4 _117 = t0.GatherRed(s0, _115);
        float _126 = (_74 * _117.x) - _84;
        float _127 = (_74 * _117.y) - _84;
        float _128 = (_74 * _117.z) - _84;
        float _129 = (_74 * _117.w) - _84;
        float4 _132 = t5.GatherRed(s0, _77);
        float _137 = _97 * 0.707106769084930419921875f;
        float _138 = _89 * 0.447213590145111083984375f;
        float _140 = _129 * 0.3535533845424652099609375f;
        float _141 = _128 * 0.447213590145111083984375f;
        float _142 = _126 * 0.447213590145111083984375f;
        float _148 = abs(_137 + _138);
        float _149 = abs(_138 + _140);
        float _154 = max(1.0f - min(min(_148, _149), abs(_89)), 0.0f);
        float _157 = abs((_90 * 0.707106769084930419921875f) + _141);
        float _158 = abs((_92 * 0.5f) + _142);
        float _159 = abs(mad(_90, 0.707106769084930419921875f, _96));
        float _160 = abs(mad(_92, 0.5f, _98));
        float _169 = max(1.0f - min(min(_157, _159), abs(_90)), 0.0f);
        float _170 = max(1.0f - min(abs(_92), min(_160, _158)), 0.0f);
        float _179 = abs(mad(_99, asfloat(0x7f800000u), _91));
        float _180 = abs(mad(_127, 0.707106769084930419921875f, _91));
        float _185 = max(1.0f - min(min(_179, _180), abs(_91)), 0.0f);
        float4 _191 = t5.GatherRed(s0, _59);
        float _196 = _113 * 0.447213590145111083984375f;
        float _201 = abs(mad(_114, 0.5f, _96));
        float _202 = abs(mad(_112, 0.707106769084930419921875f, _98));
        float _211 = max(1.0f - min(min(_159, _201), abs(_96)), 0.0f);
        float _212 = max(1.0f - min(abs(_98), min(_202, _160)), 0.0f);
        float _216 = abs(_137 + _196);
        float _221 = max(1.0f - min(min(_148, _216), abs(_97)), 0.0f);
        float _227 = abs(mad(_99, asfloat(0x7f800000u), _111));
        float _232 = max(1.0f - min(min(_179, _227), abs(_99)), 0.0f);
        float4 _236 = t5.GatherRed(s0, _100);
        float _242 = abs(mad(_127, 0.707106769084930419921875f, _111));
        float _247 = max(1.0f - min(min(_227, _242), abs(_111)), 0.0f);
        float _253 = abs((_112 * 0.707106769084930419921875f) + _142);
        float _254 = abs((_114 * 0.5f) + _141);
        float _263 = max(1.0f - min(min(_253, _202), abs(_112)), 0.0f);
        float _264 = max(1.0f - min(abs(_114), min(_201, _254)), 0.0f);
        float _267 = abs(_196 + _140);
        float _272 = max(1.0f - min(min(_216, _267), abs(_113)), 0.0f);
        float4 _278 = t5.GatherRed(s0, _115);
        float _295 = max(1.0f - min(min(_253, _158), abs(_126)), 0.0f);
        float _296 = max(1.0f - min(abs(_128), min(_157, _254)), 0.0f);
        float _297 = max(1.0f - min(abs(_129), min(_149, _267)), 0.0f);
        float _304 = max(1.0f - min(min(_180, _242), abs(_127)), 0.0f);
        float result = mad(_297, _278.w, mad(_296, _278.z, mad(_278.y, _304, mad(_278.x, _295, mad(_236.w, _264, mad(_236.z, _272, mad(_236.y, _263, mad(_236.x, _247, mad(_191.w, _232, mad(_191.z, _212, mad(_191.y, _221, mad(_191.x, _211, mad(_132.w, _170, mad(_132.z, _185, (_132.y * _169) + (_132.x * _154))))))))))))))) / mad(_297, 1.0f, mad(_296, 1.0f, mad(_304, 1.0f, mad(_295, 1.0f, mad(_264, 1.0f, mad(_272, 1.0f, mad(_263, 1.0f, mad(_247, 1.0f, mad(_232, 1.0f, mad(_212, 1.0f, mad(_221, 1.0f, mad(_211, 1.0f, mad(_170, 1.0f, mad(_185, 1.0f, (_154 * 1.0f) + (_169 * 1.0f)))))))))))))));
        ao = pow(result, GS_AmbientOcclusion);
    }
    return ao;
}
#elif AO_DENOISE_VARIANT == 1
float Denoise()
{
    float ao = 1.0f;
    float _99 = asfloat(cb1_m[44u].z);
    float _100 = asfloat(cb1_m[44u].w);
    float _106 = mad(_99, -0.5f, TEXCOORD.x);
    float _107 = mad(_100, -0.5f, TEXCOORD.y);
    float2 _110 = float2(_106, _107);
    float4 _113 = t0.GatherRed(s0, _110);
    float _115 = _113.y;
    if (_115 < 65504.0f)
    {
        float _124 = 1.0f / (_115 * 0.00999999977648258209228515625f);
        float _125 = 1.0f / (_115 * 0.100000001490116119384765625f);
        float _126 = mad(_100, 1.5f, TEXCOORD.y);
        float _127 = mad(_99, 1.5f, TEXCOORD.x);
        float2 _128 = float2(_106, _126);
        float4 _130 = t0.GatherRed(s0, _128);
        float _135 = _115 * _124;
        float _140 = (_124 * _130.x) - _135;
        float _141 = (_124 * _130.y) - _135;
        float _142 = (_124 * _130.z) - _135;
        float _143 = (_124 * _130.w) - _135;
        float2 _144 = float2(_127, _126);
        float4 _146 = t0.GatherRed(s0, _144);
        float _155 = (_124 * _146.x) - _135;
        float _156 = (_124 * _146.y) - _135;
        float _157 = (_124 * _146.z) - _135;
        float _158 = (_124 * _146.w) - _135;
        float _159 = _99 * 0.5f;
        float _160 = _100 * 0.5f;
        float _161 = mad(_99, 0.5f, TEXCOORD.x);
        float _162 = mad(_100, 0.5f, TEXCOORD.y);
        float2 _163 = float2(_127, _107);
        float4 _165 = t0.GatherRed(s0, _163);
        float _174 = (_124 * _165.x) - _135;
        float _175 = (_124 * _165.y) - _135;
        float _176 = (_124 * _165.z) - _135;
        float _177 = (_124 * _165.w) - _135;
        float _181 = (_113.x * _124) - _135;
        float _182 = _135 - _135;
        float _183 = (_113.z * _124) - _135;
        float _184 = (_113.w * _124) - _135;
        float4 _187 = t5.GatherRed(s0, _128);
        float _192 = _156 * 0.3535533845424652099609375f;
        float _193 = _155 * 0.447213590145111083984375f;
        float _194 = _157 * 0.447213590145111083984375f;
        float _196 = _140 * 0.447213590145111083984375f;
        float _201 = _184 * 0.707106769084930419921875f;
        float _203 = abs(_196 + _192);
        float _204 = abs(_201 + _196);
        float _209 = max(1.0f - min(min(_203, _204), abs(_140)), 0.0f);
        float _212 = abs((_141 * 0.5f) + _193);
        float _213 = abs((_143 * 0.707106769084930419921875f) + _194);
        float _214 = abs(mad(_141, 0.5f, _183));
        float _215 = abs(mad(_143, 0.707106769084930419921875f, _181));
        float _224 = max(1.0f - min(min(_212, _214), abs(_141)), 0.0f);
        float _225 = max(1.0f - min(abs(_143), min(_215, _213)), 0.0f);
        float _234 = abs(mad(_158, 0.707106769084930419921875f, _142));
        float _235 = abs(mad(_182, asfloat(0x7f800000u), _142));
        float _240 = max(1.0f - min(min(_234, _235), abs(_142)), 0.0f);
        float4 _246 = t5.GatherRed(s0, _144);
        float _252 = _176 * 0.447213590145111083984375f;
        float _257 = abs((_177 * 0.707106769084930419921875f) + _193);
        float _258 = abs(_252 + _192);
        float _259 = abs((_175 * 0.5f) + _194);
        float _272 = max(1.0f - min(min(_212, _257), abs(_155)), 0.0f);
        float _273 = max(1.0f - min(abs(_156), min(_203, _258)), 0.0f);
        float _274 = max(1.0f - min(abs(_157), min(_259, _213)), 0.0f);
        float _282 = abs(mad(_158, 0.707106769084930419921875f, _174));
        float _287 = max(1.0f - min(min(_234, _282), abs(_158)), 0.0f);
        float4 _291 = t5.GatherRed(s0, _163);
        float _297 = abs(mad(_182, asfloat(0x7f800000u), _174));
        float _302 = max(1.0f - min(min(_282, _297), abs(_174)), 0.0f);
        float _307 = abs(mad(_175, 0.5f, _181));
        float _308 = abs(mad(_177, 0.707106769084930419921875f, _183));
        float _317 = max(1.0f - min(min(_307, _259), abs(_175)), 0.0f);
        float _318 = max(1.0f - min(abs(_177), min(_257, _308)), 0.0f);
        float _322 = abs(_201 + _252);
        float _327 = max(1.0f - min(min(_322, _258), abs(_176)), 0.0f);
        float4 _333 = t5.GatherRed(s0, _110);
        float _346 = max(1.0f - min(min(_307, _215), abs(_181)), 0.0f);
        float _347 = max(1.0f - min(abs(_183), min(_214, _308)), 0.0f);
        float _354 = max(1.0f - min(min(_235, _297), abs(_182)), 0.0f);
        float _363 = max(1.0f - min(min(_204, _322), abs(_184)), 0.0f);
        float _366 = mad(_333.w, _363, mad(_333.z, _347, mad(_333.y, _354, mad(_333.x, _346, mad(_291.w, _318, mad(_291.z, _327, mad(_291.y, _317, mad(_291.x, _302, mad(_246.w, _287, mad(_246.z, _274, mad(_246.y, _273, mad(_246.x, _272, mad(_187.w, _225, mad(_187.z, _240, (_187.y * _224) + (_187.x * _209))))))))))))))) / mad(_363, 1.0f, mad(_347, 1.0f, mad(_354, 1.0f, mad(_346, 1.0f, mad(_318, 1.0f, mad(_327, 1.0f, mad(_317, 1.0f, mad(_302, 1.0f, mad(_287, 1.0f, mad(_274, 1.0f, mad(_273, 1.0f, mad(_272, 1.0f, mad(_225, 1.0f, mad(_240, 1.0f, (_209 * 1.0f) + (_224 * 1.0f)))))))))))))));
        float4 _370 = t3.SampleLevel(s0, float2(TEXCOORD.x, TEXCOORD.y), 0.0f);
        float _371 = _370.x;
        float _372 = _370.y;
        float _373 = abs(_371);
        float _374 = abs(_372);
        float _375 = _373 - 0.5f;
        float _376 = _374 - 0.5f;
        float _389 = (clamp(_375 + _375, 0.0f, 1.0f) * 30.0f) + (min(_373 + _373, 1.0f) * 10.0f);
        float _390 = (clamp(_376 + _376, 0.0f, 1.0f) * 30.0f) + (min(_374 + _374, 1.0f) * 10.0f);
        float _395 = (_371 >= 0.0f) ? _389 : (-_389);
        float _396 = (_372 >= 0.0f) ? _390 : (-_390);
        float _398 = mad(-_160, _396, TEXCOORD.y);
        float _400 = mad(-_159, _395, TEXCOORD.x);
        float4 _404 = t4.SampleLevel(s0, float2(_400, _398), 0.0f);
        float _405 = _404.x;
        float _406 = _404.y;
        float _407 = abs(_405);
        float _408 = abs(_406);
        float _409 = _407 - 0.5f;
        float _410 = _408 - 0.5f;
        float _423 = (min(_407 + _407, 1.0f) * 10.0f) + (clamp(_409 + _409, 0.0f, 1.0f) * 30.0f);
        float _424 = (clamp(_410 + _410, 0.0f, 1.0f) * 30.0f) + (min(_408 + _408, 1.0f) * 10.0f);
        float _429 = (_405 >= 0.0f) ? _423 : (-_423);
        float _430 = (_406 >= 0.0f) ? _424 : (-_424);
        float _432 = mad(-_160, _430, _398);
        float _434 = mad(-_159, _429, _400);
        float4 _438 = t7.GatherRed(s0, float2(_434, _432));
        float _447 = mad(_432, asfloat(cb1_m[44u].y), -0.498046875f);
        float _448 = mad(_434, asfloat(cb1_m[44u].x), -0.498046875f);
        int _449 = cvt_f32_i32(_448);
        int _450 = cvt_f32_i32(_447);
        uint _452 = uint(_450 + 1);
        uint _454 = uint(_449 + 1);
        uint _456 = uint(_449);
        uint _463 = uint(_450);
        float2 _470 = float2(_395, _396);
        float2 _472 = float2(_429, _430);
        float _478 = asfloat((asint(max(dp2_f32(_470, _470), dp2_f32(_472, _472))) >> int(1u)) + 532487669);
        float _491 = frac(_447);
        float _492 = frac(_448);
        float _493 = 1.0f - _492;
        float _494 = 1.0f - _491;
        float _527 = mad(_494 * _493, mad(_438.w - _366, clamp(mad(-_125, _115 - t2.Load(int3(uint2(_456, _463), 0u)).x, 1.0f), 0.0f, 1.0f), _366), mad(_494 * _492, mad(_438.z - _366, clamp(mad(-_125, _115 - t2.Load(int3(uint2(_454, _463), 0u)).x, 1.0f), 0.0f, 1.0f), _366), ((_492 * _491) * mad(_438.y - _366, clamp(mad(-_125, _115 - t2.Load(int3(uint2(_454, _452), 0u)).x, 1.0f), 0.0f, 1.0f), _366)) + ((_491 * _493) * mad(clamp(mad(-_125, _115 - t2.Load(int3(uint2(_456, _452), 0u)).x, 1.0f), 0.0f, 1.0f), _438.x - _366, _366))));
        float _530 = t5.SampleLevel(s0, _110, 0.0f).x;
        float _534 = t5.SampleLevel(s0, float2(_161, _162), 0.0f).x;
        float _538 = t5.SampleLevel(s0, float2(_106, _162), 0.0f).x;
        float _542 = t5.SampleLevel(s0, float2(_161, _107), 0.0f).x;
        float _546 = min(_366, min(_530, min(_534, min(_538, _542))));
        float _550 = max(_366, max(_530, max(_534, max(_538, _542))));
        float2 _553 = float2(_395 - _429, _396 - _430);
        float _560 = clamp(mad(asfloat((asint(dp2_f32(_553, _553)) >> int(1u)) + 532487669), -0.25f, 1.0f), 0.0f, 1.0f);
        float _565 = (mad(_560, -2.0f, 3.0f) * (_560 * _560)) * (_550 - _546);
        float _566 = mad(_565, -0.5f, _546);
        float _567 = mad(_565, 0.5f, _550);
        float result = mad(mad(clamp(_478, 0.0f, 1.0f), cb8_m1.x - cb8_m1.y, cb8_m1.y) * clamp(40.0f - _478, 0.0f, 1.0f), clamp(_527, _566, min(max(_527, _567), max(_566, _567))) - _366, _366);
        ao = pow(result, GS_AmbientOcclusion);
    }
    return ao;
}
#else
float Denoise()
{
    float ao = 1.0f;
    float _99 = asfloat(cb1_m[44u].z);
    float _100 = asfloat(cb1_m[44u].w);
    float _101 = _100 * 0.5f;
    float _102 = _99 * 0.5f;
    float _108 = mad(_99, 0.5f, TEXCOORD.x);
    float _109 = mad(_100, 0.5f, TEXCOORD.y);
    float2 _112 = float2(_108, _109);
    float4 _115 = t0.GatherRed(s0, _112);
    float _119 = _115.w;
    if (_119 < 65504.0f)
    {
        float _126 = 1.0f / (_119 * 0.00999999977648258209228515625f);
        float _127 = 1.0f / (_119 * 0.100000001490116119384765625f);
        float _128 = mad(_99, -1.5f, TEXCOORD.x);
        float _129 = mad(_100, -1.5f, TEXCOORD.y);
        float2 _130 = float2(_128, _109);
        float4 _132 = t0.GatherRed(s0, _130);
        float _137 = _119 * _126;
        float _142 = (_126 * _132.x) - _137;
        float _143 = (_126 * _132.y) - _137;
        float _144 = (_126 * _132.z) - _137;
        float _145 = (_126 * _132.w) - _137;
        float _149 = (_115.x * _126) - _137;
        float _150 = (_115.y * _126) - _137;
        float _151 = (_115.z * _126) - _137;
        float _152 = _137 - _137;
        float2 _153 = float2(_108, _129);
        float4 _155 = t0.GatherRed(s0, _153);
        float _164 = (_126 * _155.x) - _137;
        float _165 = (_126 * _155.y) - _137;
        float _166 = (_126 * _155.z) - _137;
        float _167 = (_126 * _155.w) - _137;
        float _168 = mad(_99, -0.5f, TEXCOORD.x);
        float _169 = mad(_100, -0.5f, TEXCOORD.y);
        float2 _170 = float2(_128, _129);
        float4 _172 = t0.GatherRed(s0, _170);
        float _181 = (_126 * _172.x) - _137;
        float _182 = (_126 * _172.y) - _137;
        float _183 = (_126 * _172.z) - _137;
        float _184 = (_126 * _172.w) - _137;
        float4 _187 = t5.GatherRed(s0, _130);
        float _192 = _150 * 0.707106769084930419921875f;
        float _193 = _142 * 0.447213590145111083984375f;
        float _195 = _184 * 0.3535533845424652099609375f;
        float _196 = _183 * 0.447213590145111083984375f;
        float _197 = _181 * 0.447213590145111083984375f;
        float _203 = abs(_192 + _193);
        float _204 = abs(_193 + _195);
        float _209 = max(1.0f - min(min(_203, _204), abs(_142)), 0.0f);
        float _212 = abs((_143 * 0.707106769084930419921875f) + _196);
        float _213 = abs((_145 * 0.5f) + _197);
        float _214 = abs(mad(_143, 0.707106769084930419921875f, _149));
        float _215 = abs(mad(_145, 0.5f, _151));
        float _224 = max(1.0f - min(min(_212, _214), abs(_143)), 0.0f);
        float _225 = max(1.0f - min(abs(_145), min(_215, _213)), 0.0f);
        float _234 = abs(mad(_182, 0.707106769084930419921875f, _144));
        float _235 = abs(mad(_152, asfloat(0x7f800000u), _144));
        float _240 = max(1.0f - min(min(_234, _235), abs(_144)), 0.0f);
        float4 _246 = t5.GatherRed(s0, _112);
        float _251 = _166 * 0.447213590145111083984375f;
        float _256 = abs(mad(_167, 0.5f, _149));
        float _257 = abs(mad(_165, 0.707106769084930419921875f, _151));
        float _266 = max(1.0f - min(min(_214, _256), abs(_149)), 0.0f);
        float _267 = max(1.0f - min(abs(_151), min(_257, _215)), 0.0f);
        float _271 = abs(_192 + _251);
        float _276 = max(1.0f - min(min(_203, _271), abs(_150)), 0.0f);
        float _282 = abs(mad(_152, asfloat(0x7f800000u), _164));
        float _287 = max(1.0f - min(min(_235, _282), abs(_152)), 0.0f);
        float4 _291 = t5.GatherRed(s0, _153);
        float _297 = abs(mad(_182, 0.707106769084930419921875f, _164));
        float _302 = max(1.0f - min(min(_282, _297), abs(_164)), 0.0f);
        float _308 = abs((_165 * 0.707106769084930419921875f) + _197);
        float _309 = abs((_167 * 0.5f) + _196);
        float _318 = max(1.0f - min(min(_308, _257), abs(_165)), 0.0f);
        float _319 = max(1.0f - min(abs(_167), min(_256, _309)), 0.0f);
        float _322 = abs(_251 + _195);
        float _327 = max(1.0f - min(min(_271, _322), abs(_166)), 0.0f);
        float4 _333 = t5.GatherRed(s0, _170);
        float _350 = max(1.0f - min(min(_308, _213), abs(_181)), 0.0f);
        float _351 = max(1.0f - min(abs(_183), min(_212, _309)), 0.0f);
        float _352 = max(1.0f - min(abs(_184), min(_204, _322)), 0.0f);
        float _359 = max(1.0f - min(min(_234, _297), abs(_182)), 0.0f);
        float _366 = mad(_333.w, _352, mad(_333.z, _351, mad(_333.y, _359, mad(_333.x, _350, mad(_291.w, _319, mad(_291.z, _327, mad(_291.y, _318, mad(_291.x, _302, mad(_246.w, _287, mad(_246.z, _267, mad(_246.y, _276, mad(_246.x, _266, mad(_187.w, _225, mad(_187.z, _240, (_187.y * _224) + (_187.x * _209))))))))))))))) / mad(_352, 1.0f, mad(_351, 1.0f, mad(_359, 1.0f, mad(_350, 1.0f, mad(_319, 1.0f, mad(_327, 1.0f, mad(_318, 1.0f, mad(_302, 1.0f, mad(_287, 1.0f, mad(_267, 1.0f, mad(_276, 1.0f, mad(_266, 1.0f, mad(_225, 1.0f, mad(_240, 1.0f, (_209 * 1.0f) + (_224 * 1.0f)))))))))))))));
        float4 _370 = t3.SampleLevel(s0, float2(TEXCOORD.x, TEXCOORD.y), 0.0f);
        float _371 = _370.x;
        float _372 = _370.y;
        float _373 = abs(_371);
        float _374 = abs(_372);
        float _375 = _373 - 0.5f;
        float _376 = _374 - 0.5f;
        float _389 = (clamp(_375 + _375, 0.0f, 1.0f) * 30.0f) + (min(_373 + _373, 1.0f) * 10.0f);
        float _390 = (clamp(_376 + _376, 0.0f, 1.0f) * 30.0f) + (min(_374 + _374, 1.0f) * 10.0f);
        float _395 = (_371 >= 0.0f) ? _389 : (-_389);
        float _396 = (_372 >= 0.0f) ? _390 : (-_390);
        float _398 = mad(-_101, _396, TEXCOORD.y);
        float _400 = mad(-_102, _395, TEXCOORD.x);
        float4 _404 = t4.SampleLevel(s0, float2(_400, _398), 0.0f);
        float _405 = _404.x;
        float _406 = _404.y;
        float _407 = abs(_405);
        float _408 = abs(_406);
        float _409 = _407 - 0.5f;
        float _410 = _408 - 0.5f;
        float _423 = (min(_407 + _407, 1.0f) * 10.0f) + (clamp(_409 + _409, 0.0f, 1.0f) * 30.0f);
        float _424 = (clamp(_410 + _410, 0.0f, 1.0f) * 30.0f) + (min(_408 + _408, 1.0f) * 10.0f);
        float _429 = (_405 >= 0.0f) ? _423 : (-_423);
        float _430 = (_406 >= 0.0f) ? _424 : (-_424);
        float _432 = mad(-_101, _430, _398);
        float _434 = mad(-_102, _429, _400);
        float4 _438 = t7.GatherRed(s0, float2(_434, _432));
        float _447 = mad(_432, asfloat(cb1_m[44u].y), -0.498046875f);
        float _448 = mad(_434, asfloat(cb1_m[44u].x), -0.498046875f);
        int _449 = cvt_f32_i32(_448);
        int _450 = cvt_f32_i32(_447);
        uint _452 = uint(_450 + 1);
        uint _454 = uint(_449 + 1);
        uint _456 = uint(_449);
        uint _463 = uint(_450);
        float2 _470 = float2(_395, _396);
        float2 _472 = float2(_429, _430);
        float _478 = asfloat((asint(max(dp2_f32(_470, _470), dp2_f32(_472, _472))) >> int(1u)) + 532487669);
        float _491 = frac(_447);
        float _492 = frac(_448);
        float _493 = 1.0f - _492;
        float _494 = 1.0f - _491;
        float _527 = mad(_494 * _493, mad(_438.w - _366, clamp(mad(-_127, _119 - t2.Load(int3(uint2(_456, _463), 0u)).x, 1.0f), 0.0f, 1.0f), _366), mad(_494 * _492, mad(_438.z - _366, clamp(mad(-_127, _119 - t2.Load(int3(uint2(_454, _463), 0u)).x, 1.0f), 0.0f, 1.0f), _366), ((_492 * _491) * mad(_438.y - _366, clamp(mad(-_127, _119 - t2.Load(int3(uint2(_454, _452), 0u)).x, 1.0f), 0.0f, 1.0f), _366)) + ((_491 * _493) * mad(clamp(mad(-_127, _119 - t2.Load(int3(uint2(_456, _452), 0u)).x, 1.0f), 0.0f, 1.0f), _438.x - _366, _366))));
        float _531 = t5.SampleLevel(s0, float2(_168, _169), 0.0f).x;
        float _534 = t5.SampleLevel(s0, _112, 0.0f).x;
        float _538 = t5.SampleLevel(s0, float2(_168, _109), 0.0f).x;
        float _542 = t5.SampleLevel(s0, float2(_108, _169), 0.0f).x;
        float _546 = min(_366, min(_531, min(_534, min(_538, _542))));
        float _550 = max(_366, max(_531, max(_534, max(_538, _542))));
        float2 _553 = float2(_395 - _429, _396 - _430);
        float _560 = clamp(mad(asfloat((asint(dp2_f32(_553, _553)) >> int(1u)) + 532487669), -0.25f, 1.0f), 0.0f, 1.0f);
        float _565 = (mad(_560, -2.0f, 3.0f) * (_560 * _560)) * (_550 - _546);
        float _566 = mad(_565, -0.5f, _546);
        float _567 = mad(_565, 0.5f, _550);
        float result = mad(mad(clamp(_478, 0.0f, 1.0f), cb8_m1.x - cb8_m1.y, cb8_m1.y) * clamp(40.0f - _478, 0.0f, 1.0f), clamp(_527, _566, min(max(_527, _567), max(_566, _567))) - _366, _366);
        ao = pow(result, GS_AmbientOcclusion);
    }
    return ao;
}
#endif

[numthreads(8, 8, 1)]
void denoise_cs(uint3 id : SV_DispatchThreadID)
{
    if (!SetupPixel(id.xy)) return;
    uOut[id.xy] = Denoise();
}
