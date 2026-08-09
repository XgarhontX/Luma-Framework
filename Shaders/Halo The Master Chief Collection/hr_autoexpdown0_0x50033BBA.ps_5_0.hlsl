// ---- Created with 3Dmigoto v1.3.16 on Wed Aug 05 17:39:50 2026

cbuffer PostProcessPS : register(b0)
{
  float4 pixel_size : packoffset(c0);
  float4 scale : packoffset(c1);
  float4x3 p_postprocess_hue_saturation_matrix : packoffset(c2);
  float4 p_postprocess_contrast : packoffset(c5);
}

SamplerState LocalSampler_source_sampler_s : register(s0);
Texture2D<float4> LocalTexture_source_sampler : register(t0);


// 3Dmigoto declarations
#define cmp -


void main(
  float4 v0 : SV_Position0,
  float2 v1 : TEXCOORD0,
  out float4 o0 : SV_Target0)
{
  float4 r0;
  uint4 bitmask, uiDest;
  float4 fDest;

  r0.xy = v1.xy * scale.xy + scale.zw;
  r0.xyz = LocalTexture_source_sampler.Sample(LocalSampler_source_sampler_s, r0.xy).xyz;
  r0.xyz = max(r0.xyz, 0);
  // r0.xyz = pow(r0.xyz, 2.2);
  // o0.xyz = saturate(r0.xyz);
  o0.xyz = r0.xyz;
  o0.w = 1;
  return;
}