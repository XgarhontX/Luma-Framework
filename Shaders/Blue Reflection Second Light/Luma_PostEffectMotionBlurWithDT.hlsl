// ---- Created with 3Dmigoto v1.3.16 on Sun May 24 11:42:57 2026

cbuffer _Globals : register(b0)
{
  row_major float4x4 _CurrentViewProjectionInverseMatrix : packoffset(c0);
  row_major float4x4 _PreviousViewProjectionMatrix : packoffset(c4);
  float _BlurSize : packoffset(c8);
  float4 vCameraAtPosition : packoffset(c9);
}

SamplerState smplDepth_s : register(s0);
SamplerState smplScene_s : register(s1);
SamplerState smplStencil_s : register(s2);
Texture2D<float4> smplDepth_Tex : register(t0);
Texture2D<float4> smplScene_Tex : register(t1);
Texture2D<float4> smplStencil_Tex : register(t2);


// 3Dmigoto declarations
#define cmp -


void main(
  float4 v0 : SV_Position0,
  float2 v1 : TEXCOORD0,
  out float4 o0 : SV_Target0)
{
  float4 r0,r1,r2,r3,r4,r5;
  uint4 bitmask, uiDest;
  float4 fDest;

  r2.xyzw = smplScene_Tex.Sample(smplScene_s, v1.xy).xyzw;
  o0.xyz = r2.xyz;
  o0.w = r2.w;
  return;
}