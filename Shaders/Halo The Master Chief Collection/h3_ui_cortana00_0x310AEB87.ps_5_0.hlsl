// ---- Created with 3Dmigoto v1.3.16 on Wed Aug 05 15:06:09 2026

cbuffer CHUDPS : register(b0)
{
  float4 chud_color_output_A : packoffset(c0);
  float4 chud_color_output_B : packoffset(c1);
  float4 chud_color_output_C : packoffset(c2);
  float4 chud_color_output_D : packoffset(c3);
  float4 chud_color_output_E : packoffset(c4);
  float4 chud_color_output_F : packoffset(c5);
  float4 chud_scalar_output_ABCD : packoffset(c6);
  float4 chud_scalar_output_EF : packoffset(c7);
  float4 chud_texture_bounds : packoffset(c8);
  float4 chud_savedfilm_chap1 : packoffset(c9);
  float4 chud_savedfilm_chap2 : packoffset(c10);
  float4 chud_savedfilm_chap3 : packoffset(c11);
  float4 chud_savedfilm_data : packoffset(c12);
  bool chud_cortana_pixel : packoffset(c13);
  bool chud_comp_colorize_enabled : packoffset(c13.y);
}

cbuffer CHUDCortanaPS : register(b1)
{
  float4 cortana_back_colormix_result : packoffset(c0);
  float4 cortana_back_hsv_result : packoffset(c1);
  float4 cortana_texcam_colormix_result : packoffset(c2);
  float4 cortana_comp_solarize_inmix : packoffset(c3);
  float4 cortana_comp_solarize_outmix : packoffset(c4);
  float4 cortana_comp_solarize_result : packoffset(c5);
  float4 cortana_comp_doubling_inmix : packoffset(c6);
  float4 cortana_comp_doubling_outmix : packoffset(c7);
  float4 cortana_comp_doubling_result : packoffset(c8);
  float4 cortana_comp_colorize_inmix : packoffset(c9);
  float4 cortana_comp_colorize_outmix : packoffset(c10);
  float4 cortana_comp_colorize_result : packoffset(c11);
  float4 cortana_texcam_bloom_inmix : packoffset(c12);
  float4 cortana_texcam_bloom_outmix : packoffset(c13);
  float4 cortana_texcam_bloom_result : packoffset(c14);
  float4 cortana_vignette_data : packoffset(c15);
}

cbuffer PostProcessPS : register(b2)
{
  float4 ps_postprocess_pixel_size : packoffset(c0);
  float4 ps_postprocess_scale : packoffset(c1);
  float4x3 ps_postprocess_hue_saturation_matrix : packoffset(c2);
  float4 ps_postprocess_contrast : packoffset(c5);
}

SamplerState LocalSampler_basemap_sampler_s : register(s0);
SamplerState LocalSampler_cortana_sampler_s : register(s1);
SamplerState LocalSampler_goo_sampler_s : register(s2);
Texture2D<float4> LocalTexture_basemap_sampler : register(t0);
Texture2D<float4> LocalTexture_cortana_sampler : register(t1);
Texture2D<float4> LocalTexture_goo_sampler : register(t2);


// 3Dmigoto declarations
#define cmp -
#include "./Includes/Common.hlsl"

void main(
  float4 v0 : SV_Position0,
  float2 v1 : TEXCOORD0,
  float2 w1 : TEXCOORD2,
  float4 v2 : TEXCOORD1,
  float v3 : TEXCOORD3,
  out float4 o0 : SV_Target0)
{
  float4 r0,r1,r2,r3;
  uint4 bitmask, uiDest;
  float4 fDest;

  r0.xyzw = float4(0.800000012,0.800000012,0.5,0.5) * cortana_comp_doubling_result.zzzz;
  r1.xyzw = v3.xxxx * v1.xyxy;
  r2.xyzw = r1.xyzw * float4(2,2,2,2) + float4(-1,-1,-1,-1);
  r0.xyzw = r2.xyzw * r0.xyzw;
  r0.xyzw = r0.xyzw * float4(0.5,0.5,0.5,0.5) + float4(0.5,0.5,0.5,0.5);
  r2.xyzw = LocalTexture_cortana_sampler.Sample(LocalSampler_cortana_sampler_s, r0.xy).xyzw;
  r0.xyzw = LocalTexture_cortana_sampler.Sample(LocalSampler_cortana_sampler_s, r0.zw).xyzw;
  r0.xyzw = r2.xyzw + r0.xyzw;
  r0.x = dot(r0.xyzw, cortana_comp_doubling_inmix.xyzw);
  r2.xyzw = cortana_comp_doubling_result.xxxx * cortana_comp_doubling_outmix.xyzw;
  r3.xyzw = LocalTexture_cortana_sampler.Sample(LocalSampler_cortana_sampler_s, r1.zw).xyzw;
  r0.yzw = LocalTexture_basemap_sampler.Sample(LocalSampler_basemap_sampler_s, r1.zw).xyz;
  r0.yzw = sRGB_Encode(r0.yzw);

  r1.xyz = cortana_back_colormix_result.xyz * r0.yzw;
  r0.xyzw = r2.xyzw * r0.xxxx + r3.xyzw;
  r2.x = dot(r0.xyzw, cortana_comp_solarize_inmix.xyzw);
  r2.x = min(1, r2.x);
  r2.y = -cortana_comp_solarize_result.x + r2.x;
  r2.x = cmp(r2.x >= cortana_comp_solarize_result.x);
  r2.x = r2.x ? 1.000000 : 0;
  r2.z = 1 + -cortana_comp_solarize_result.x;
  r2.z = max(9.99999997e-007, r2.z);
  r2.y = r2.y / r2.z;
  r2.y = log2(abs(r2.y));
  r2.y = cortana_comp_solarize_result.y * r2.y;
  r2.y = exp2(r2.y);
  r2.x = r2.x * r2.y;
  r0.xyzw = r2.xxxx * cortana_comp_solarize_outmix.xyzw + r0.xyzw;
  r2.x = dot(r0.xyzw, cortana_comp_colorize_inmix.xyzw);
  r2.x = min(1, r2.x);
  r2.xyzw = cortana_comp_colorize_result.xyzw * r2.xxxx;
  r2.xyzw = cortana_comp_colorize_outmix.xyzw * r2.xyzw;
  r0.xyzw = chud_cortana_pixel ? r2.xyzw : r0.xyzw;
  r2.xy = float2(-0.5,-0.5) + v2.xy;
  r2.x = dot(r2.xy, r2.xy);
  r2.x = sqrt(r2.x);
  r2.x = -cortana_vignette_data.x + r2.x;
  r2.y = cortana_vignette_data.y + -cortana_vignette_data.x;
  r2.x = saturate(r2.x / r2.y);
  r2.x = r2.x * r2.x;
  r2.x = r3.x * 0.5 + r2.x;
  r2.xy = float2(0.400000006,0.600000024) * r2.xx;
  r3.xyzw = LocalTexture_goo_sampler.Sample(LocalSampler_goo_sampler_s, w1.xy).xyzw;
  r2.xyzw = r2.xxxx * r3.xyzw + r2.yyyy;
  r2.xyzw = float4(1,1,1,1) + -r2.xyzw;
  r3.w = 1;
  r1.w = 1;
  r3.x = dot(r1.xyzw, ps_postprocess_hue_saturation_matrix._m00_m10_m20_m30);
  r3.y = dot(r1.xyzw, ps_postprocess_hue_saturation_matrix._m01_m11_m21_m31);
  r3.z = dot(r1.xyzw, ps_postprocess_hue_saturation_matrix._m02_m12_m22_m32);
  r0.xyzw = r3.xyzw * r2.xyzw + r0.xyzw;

  // r1.xyz = float3(0.0549999997,0.0549999997,0.0549999997) + r0.xyz;
  // r1.xyz = float3(0.947867334,0.947867334,0.947867334) * r1.xyz;
  // r1.xyz = log2(r1.xyz);
  // r1.xyz = float3(2.4000001,2.4000001,2.4000001) * r1.xyz;
  // r1.xyz = exp2(r1.xyz);
  // r2.xyz = cmp(float3(0.0404499993,0.0404499993,0.0404499993) >= r0.xyz);
  // r0.xyz = float3(0.0773993805,0.0773993805,0.0773993805) * r0.xyz;
  // o0.xyz = r2.xyz ? r0.xyz : r1.xyz;
  r0.xyz = sRGB_Decode(r0.xyz);
  o0.xyz = r0.xyz;

  o0.w = r0.w;
  return;
}