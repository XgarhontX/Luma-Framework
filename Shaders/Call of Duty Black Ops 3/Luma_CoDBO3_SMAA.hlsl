cbuffer SMAAConstants : register(b0)
{
    float4 rtMetrics;
    float4 subsampleIndices;
};

SamplerState LinearSampler : register(s0);
SamplerState PointSampler : register(s1);

Texture2D<float4> tex0 : register(t0);
Texture2D<float4> tex1 : register(t1);
Texture2D<float4> tex2 : register(t2);
RWTexture2D<float4> out0 : register(u0);

#define SMAA_RT_METRICS rtMetrics
#define SMAA_CUSTOM_SL
#define SMAA_INCLUDE_VS 1
#define SMAA_INCLUDE_PS 1
#define SMAATexture2D(tex) Texture2D<float4> tex
#define SMAATexturePass2D(tex) tex
#define SMAASampleLevelZero(tex, coord) tex.SampleLevel(LinearSampler, coord, 0)
#define SMAASampleLevelZeroPoint(tex, coord) tex.SampleLevel(PointSampler, coord, 0)
#define SMAASampleLevelZeroOffset(tex, coord, offset) tex.SampleLevel(LinearSampler, coord, 0, offset)
#define SMAASample(tex, coord) tex.SampleLevel(LinearSampler, coord, 0)
#define SMAASamplePoint(tex, coord) tex.SampleLevel(PointSampler, coord, 0)
#define SMAASampleOffset(tex, coord, offset) tex.SampleLevel(LinearSampler, coord, 0, offset)
#define SMAA_FLATTEN [flatten]
#define SMAA_BRANCH [branch]

#ifndef SMAA_THRESHOLD
#define SMAA_THRESHOLD 0.1
#endif
#ifndef SMAA_MAX_SEARCH_STEPS
#define SMAA_MAX_SEARCH_STEPS 32
#endif
#ifndef SMAA_MAX_SEARCH_STEPS_DIAG
#define SMAA_MAX_SEARCH_STEPS_DIAG 16
#endif
#ifndef SMAA_CORNER_ROUNDING
#define SMAA_CORNER_ROUNDING 25
#endif
#ifndef SMAA_LOCAL_CONTRAST_ADAPTATION_FACTOR
#define SMAA_LOCAL_CONTRAST_ADAPTATION_FACTOR 2.0
#endif

#include "../Includes/SMAA.hlsl"

#define SMAA_GROUP_SIZE 8

bool SMAA_InBounds(uint2 pixel)
{
    return all(pixel < uint2(rtMetrics.zw));
}

float2 SMAA_PixelToUV(uint2 pixel)
{
    return (float2(pixel) + 0.5) * rtMetrics.xy;
}

float2 SMAA_LumaTexEdgeDetection(float2 texcoord, float4 offset[3], Texture2D<float4> lumaTex)
{
    float2 threshold = float2(SMAA_THRESHOLD, SMAA_THRESHOLD);

    float L = SMAASamplePoint(lumaTex, texcoord).r;
    float Lleft = SMAASamplePoint(lumaTex, offset[0].xy).r;
    float Ltop = SMAASamplePoint(lumaTex, offset[0].zw).r;

    float4 delta;
    delta.xy = abs(L - float2(Lleft, Ltop));
    float2 edges = step(threshold, delta.xy);
    if (dot(edges, float2(1.0, 1.0)) == 0.0)
        return float2(0.0, 0.0);

    float Lright = SMAASamplePoint(lumaTex, offset[1].xy).r;
    float Lbottom = SMAASamplePoint(lumaTex, offset[1].zw).r;
    delta.zw = abs(L - float2(Lright, Lbottom));
    float2 maxDelta = max(delta.xy, delta.zw);

    float Lleftleft = SMAASamplePoint(lumaTex, offset[2].xy).r;
    float Ltoptop = SMAASamplePoint(lumaTex, offset[2].zw).r;
    delta.zw = abs(float2(Lleft, Ltop) - float2(Lleftleft, Ltoptop));
    maxDelta = max(maxDelta.xy, delta.zw);
    float finalDelta = max(maxDelta.x, maxDelta.y);

    edges.xy *= step(finalDelta, SMAA_LOCAL_CONTRAST_ADAPTATION_FACTOR * delta.xy);
    return edges;
}

[numthreads(SMAA_GROUP_SIZE, SMAA_GROUP_SIZE, 1)]
void smaa_edge_detection_cs(uint3 id : SV_DispatchThreadID)
{
    if (!SMAA_InBounds(id.xy)) return;
    float2 texcoord = SMAA_PixelToUV(id.xy);
    float4 offset[3];
    SMAAEdgeDetectionVS(texcoord, offset);
    out0[id.xy] = float4(SMAA_LumaTexEdgeDetection(texcoord, offset, tex0), 0.0, 0.0);
}

[numthreads(SMAA_GROUP_SIZE, SMAA_GROUP_SIZE, 1)]
void smaa_blending_weight_calculation_cs(uint3 id : SV_DispatchThreadID)
{
    if (!SMAA_InBounds(id.xy)) return;
    float2 texcoord = SMAA_PixelToUV(id.xy);
    float2 pixcoord;
    float4 offset[3];
    SMAABlendingWeightCalculationVS(texcoord, pixcoord, offset);
    float2 e = tex0[id.xy].rg;
    if (dot(e, float2(1.0, 1.0)) == 0.0)
    {
        out0[id.xy] = float4(0.0, 0.0, 0.0, 0.0);
        return;
    }
    out0[id.xy] = SMAABlendingWeightCalculationPS(texcoord, pixcoord, offset, tex0, tex1, tex2, subsampleIndices);
}

[numthreads(SMAA_GROUP_SIZE, SMAA_GROUP_SIZE, 1)]
void smaa_neighborhood_blending_cs(uint3 id : SV_DispatchThreadID)
{
    if (!SMAA_InBounds(id.xy)) return;
    float2 texcoord = SMAA_PixelToUV(id.xy);
    float4 offset;
    SMAANeighborhoodBlendingVS(texcoord, offset);
    out0[id.xy] = SMAANeighborhoodBlendingPS(texcoord, offset, tex0, tex1);
}
