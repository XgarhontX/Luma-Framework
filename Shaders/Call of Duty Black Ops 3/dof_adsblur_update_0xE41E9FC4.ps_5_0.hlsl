cbuffer PostFxCBuffer : register(b8)
{
  float4 postFxControl0 : packoffset(c0);
  float4 postFxControl1 : packoffset(c1);
}

cbuffer PerSceneConsts : register(b1)
{
  float4 renderTargetSize : packoffset(c44);
  float4 gameTick : packoffset(c70);
}

SamplerState bilinearClamp_s : register(s0);
Texture2D<float4> codeTexture0 : register(t0);
Texture2D<float4> codeTexture1 : register(t1);
Texture2D<float4> codeTexture2 : register(t2);

static const float3 LUMA_W = float3(0.212599993, 0.715200007, 0.0722000003);

static const float2 KERNEL[18] = {
  float2( 0.4330127,  0.25), float2( 0.0,  0.5), float2(-0.4330127,  0.25), float2(-0.4330127, -0.25), float2( 0.0, -0.5), float2( 0.4330127, -0.25),
  float2( 1.0,  0.0), float2( 0.8660254,  0.5), float2( 0.5,  0.8660254), float2( 0.0,  1.0), float2(-0.5,  0.8660254), float2(-0.8660254,  0.5),
  float2(-1.0,  0.0), float2(-0.8660254, -0.5), float2(-0.5, -0.8660254), float2( 0.0, -1.0), float2( 0.5, -0.8660254), float2( 0.8660254, -0.5)
};

void main(
  float2 v0 : TEXCOORD0,
  float4 v1 : SV_POSITION0,
  out float3 o0 : SV_TARGET0)
{
  const float2 uv = v0.xy;
  const float3 sharp = codeTexture0.Sample(bilinearClamp_s, uv).xyz;
  const float mask = codeTexture1.Load(int3((int2)v1.xy, 0)).x;
  const float4 wide = codeTexture2.Sample(bilinearClamp_s, uv);

  float amount = (mask >= 0.984375) ? saturate(mask * postFxControl1.y + postFxControl1.z) : 1.0;
  amount = min(amount, wide.w) * postFxControl1.w;
  if (amount <= 0.0)
  {
    o0 = sharp;
    return;
  }

  const float blend = saturate(amount * 4.0 - 0.5);
  if (blend >= 1.0)
  {
    o0 = wide.xyz;
    return;
  }

  const float2 dirScale = (gameTick.y > 0.0) ? float2(1.0, -1.0) : float2(0.75, -0.75);
  const float2 radius = dirScale * (2.25 * saturate(8.0 * amount)) * renderTargetSize.zw;

  const float w0 = rcp(1.0 + dot(sharp, LUMA_W)) * 0.5;
  float4 acc = float4(sharp * w0, w0);
  [unroll] for (int i = 0; i < 18; i++)
  {
    const float3 s = codeTexture0.SampleLevel(bilinearClamp_s, uv + radius * KERNEL[i], 0).xyz;
    const float w = rcp(1.0 + dot(s, LUMA_W)) * ((i < 6) ? 1.0 : 0.75);
    acc += float4(s * w, w);
  }
  const float3 small = acc.xyz * rcp(acc.w);

  o0 = lerp(small, wide.xyz, blend);
}
