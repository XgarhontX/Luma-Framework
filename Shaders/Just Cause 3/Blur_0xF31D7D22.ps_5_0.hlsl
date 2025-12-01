cbuffer cbConsts : register(b1)
{
  float4 Consts : packoffset(c0);
}

SamplerState RenderTarget_s : register(s0);
Texture2D<float4> RenderTarget : register(t0);

void main(
  float4 v0 : SV_Position0,
  float2 v1 : TEXCOORD0,
  out float4 o0 : SV_Target0)
{
  float4 r0,r1,r2;
  float2 editedConsts = Consts.xy;
#if 0 // TODO: fix bloom being stretched horizontally in UW? It's always always stretched??? Maybe it's fine?
  editedConsts.x /= 3.5555555555555555555555555555556;
  editedConsts.y /= 1.77777777777777777777777;
#endif
  r0.xyzw = editedConsts.xyxy * float4(-7.33333302,-7.33333302,-5.42857122,-5.42857122) + v1.xyxy;
  r1.xyz = RenderTarget.Sample(RenderTarget_s, r0.zw).xyz;
  r0.xyz = RenderTarget.Sample(RenderTarget_s, r0.xy).xyz;
  r1.xyz = float3(0.0864199996,0.0864199996,0.0864199996) * r1.xyz;
  r0.xyz = r0.xyz * float3(0.0370370001,0.0370370001,0.0370370001) + r1.xyz;
  r1.xyzw = editedConsts.xyxy * float4(-3.45454502,-3.45454502,-1.46666706,-1.46666706) + v1.xyxy;
  r2.xyz = RenderTarget.Sample(RenderTarget_s, r1.xy).xyz;
  r1.xyz = RenderTarget.Sample(RenderTarget_s, r1.zw).xyz;
  r0.xyz = r2.xyz * float3(0.135802001,0.135802001,0.135802001) + r0.xyz;
  r0.xyz = r1.xyz * float3(0.185185,0.185185,0.185185) + r0.xyz;
  r1.xyz = RenderTarget.Sample(RenderTarget_s, v1.xy).xyz;
  r0.xyz = r1.xyz * float3(0.111111,0.111111,0.111111) + r0.xyz;
  r1.xyzw = editedConsts.xyxy * float4(1.46666706,1.46666706,3.45454502,3.45454502) + v1.xyxy;
  r2.xyz = RenderTarget.Sample(RenderTarget_s, r1.xy).xyz;
  r1.xyz = RenderTarget.Sample(RenderTarget_s, r1.zw).xyz;
  r0.xyz = r2.xyz * float3(0.185185,0.185185,0.185185) + r0.xyz;
  r0.xyz = r1.xyz * float3(0.135802001,0.135802001,0.135802001) + r0.xyz;
  r1.xyzw = editedConsts.xyxy * float4(5.42857122,5.42857122,7.33333302,7.33333302) + v1.xyxy;
  r2.xyz = RenderTarget.Sample(RenderTarget_s, r1.xy).xyz;
  r1.xyz = RenderTarget.Sample(RenderTarget_s, r1.zw).xyz;
  r0.xyz = r2.xyz * float3(0.0864199996,0.0864199996,0.0864199996) + r0.xyz;
  o0.xyz = r1.xyz * float3(0.0370370001,0.0370370001,0.0370370001) + r0.xyz;
  o0.w = 1;
}