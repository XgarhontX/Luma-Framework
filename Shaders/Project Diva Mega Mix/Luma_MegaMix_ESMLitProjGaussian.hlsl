// esm_gauss_litproj 0xC1A00F28

cbuffer cb0_buf : register(b0)
{
    float2 cb0_m0 : packoffset(c0);   // direction x or y
    // 0.000488281 (1st pass horizontal)
    // 0.00195312 (2nd pass vertical)

    float2 cb0_m1 : packoffset(c0.z); // bias
    // 0.01
    // 0.01

    float4 cb0_m2 : packoffset(c1);   // weights
    // (sigma 1.5)
    // 0.265962
    // 0.212965
    // 0.10934
    // 0.035994
    // 0.00759732
    // 0.00102819
    // 8.92201e-05
    // 4.96403e-06
};

SamplerState s0 : register(s0);
Texture2D<float4> t0 : register(t0);

static float2 TEXCOORD;
static float SV_Target;

struct SPIRV_Cross_Input
{
    float4 v0 : SV_Position; // unused
    // float4 v1 : TEXCOORD0; // unused
    float2 TEXCOORD : TEXCOORD1;
};

struct SPIRV_Cross_Output
{
    float SV_Target : SV_Target0;
};

float get_gaussian_weight(float x, float s)
{
    return exp(-x * x * rcp(2.0 * s * s));
}

#include "./Includes/Common.hlsl"

void frag_main()
{
    float4 _50 = t0.SampleLevel(s0, float2(TEXCOORD.x, TEXCOORD.y), 0.0f);
    float _51 = _50.x;
    if (_51 > 11.0f) // edges to sky
    {
        // quick 2 taps
        float4 _67 = t0.SampleLevel(s0, float2(TEXCOORD.x + cb0_m0.x, TEXCOORD.y + cb0_m0.y), 0.0f);
        float _68 = _67.x;
        bool _69 = _68 < 11.0f;
        float _70 = _69 ? _68 : 0.0f;
        float4 _76 = t0.SampleLevel(s0, float2(TEXCOORD.x - cb0_m0.x, TEXCOORD.y - cb0_m0.y), 0.0f);
        float _77 = _76.x;
        bool _78 = _77 < 11.0f;
        SV_Target = ((_78 ? (_77 + _70) : _70) / (_78 ? (_69 ? 2.000010013580322265625f : 1.000010013580322265625f) : (_69 ? 1.000010013580322265625f : 9.9999997473787516355514526367188e-06f))) + cb0_m1.x;
    }
    else
    {
        // // 6 taps
        // float _91 = _51 + cb0_m1.y;
        // float _99 = TEXCOORD.x + cb0_m0.x;
        // float _100 = TEXCOORD.y + cb0_m0.y;
        // float _101 = TEXCOORD.x - cb0_m0.x;
        // float _102 = TEXCOORD.y - cb0_m0.y;
        // float4 _105 = t0.SampleLevel(s0, float2(_99, _100), 0.0f);
        // float _106 = _105.x;
        // float4 _117 = t0.SampleLevel(s0, float2(_101, _102), 0.0f);
        // float _118 = _117.x;
        // float _122 = _99 + cb0_m0.x;
        // float _123 = cb0_m0.y + _100;
        // float _124 = _101 - cb0_m0.x;
        // float _125 = _102 - cb0_m0.y;
        // float4 _128 = t0.SampleLevel(s0, float2(_122, _123), 0.0f);
        // float _129 = _128.x;
        // float4 _138 = t0.SampleLevel(s0, float2(_124, _125), 0.0f);
        // float _139 = _138.x;
        // float4 _149 = t0.SampleLevel(s0, float2(_122 + cb0_m0.x, cb0_m0.y + _123), 0.0f);
        // float _150 = _149.x;
        // float4 _159 = t0.SampleLevel(s0, float2(_124 - cb0_m0.x, _125 - cb0_m0.y), 0.0f);
        // float _160 = _159.x;
        // SV_Target = mad(cb0_m2.w, (_160 > 11.0f) ? _91 : _160, mad(cb0_m2.w, (_150 > 11.0f) ? _91 : _150, mad(cb0_m2.z, (_139 > 11.0f) ? _91 : _139, mad(cb0_m2.z, (_129 > 11.0f) ? _91 : _129, mad((_118 > 11.0f) ? _91 : _118, cb0_m2.y, (_51 * cb0_m2.x) + (cb0_m2.y * ((_106 > 11.0f) ? _91 : _106))))))) / (mad(cb0_m2.w, 2.0f, mad(cb0_m2.z, 2.0f, mad(cb0_m2.y, 2.0f, cb0_m2.x))) + 9.9999997473787516355514526367188e-06f);

        const float newSizeRatio = 2; // TODO: user
        const float newSizeRatioInv = 1 / newSizeRatio;

        const float centerBiased = _51 + cb0_m1.y; // backup to use when tap sample is sky
        float cSum = _51; // color accumulator/sum, init = center
        float wSum = 1.0; // weight accumulator/sum, init = fully center

        const float sigma = 1.5 * newSizeRatio;
        const float2 radius = 3 * newSizeRatio;
        float2 step = cb0_m0 * newSizeRatioInv; // which axis?
        [unroll] for (float i = 1; i <= radius.x; i++)
        {
            // pos & neg
            float a = t0.SampleLevel(s0, TEXCOORD + step * i, 0).x;
            float b = t0.SampleLevel(s0, TEXCOORD - step * i, 0).x;

            // weight
            float w = get_gaussian_weight(i, sigma);

            // color accum: use if not sky
            cSum += w * ((a > 11.0f) ? centerBiased : a);
            cSum += w * ((b > 11.0f) ? centerBiased : b);

            // weight accum: 2 samples
            wSum += 2 * w;
        }

        // weighted sum safe
        SV_Target = cSum / (wSum + 1e-5);
    }
}

SPIRV_Cross_Output Gaussian(SPIRV_Cross_Input stage_input)
{
    TEXCOORD = stage_input.TEXCOORD;
    frag_main();
    SPIRV_Cross_Output stage_output;
    stage_output.SV_Target = SV_Target;
    return stage_output;
}
