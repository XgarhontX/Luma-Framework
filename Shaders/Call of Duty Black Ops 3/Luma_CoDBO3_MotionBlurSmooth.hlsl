#include "./Includes/Common.hlsl"

Texture2D<float4> colorTex : register(t0);
Texture2D<float4> velocityTex : register(t1);
Texture2D<float4> tileTex : register(t2);
SamplerState linearSampler : register(s0);

float2 MBS_DecodeVelocity(float2 e)
{
  return e * 127.5 - 64.0;
}

void main(float4 pos : SV_Position, out float4 o0 : SV_Target0)
{
  uint width, height;
  colorTex.GetDimensions(width, height);
  const float2 invSize = 1.0 / float2(width, height);
  const float2 uv = pos.xy * invSize;

  const float4 center = colorTex.Load(int3(pos.xy, 0));
  o0 = center;

  const float4 tile = tileTex.SampleLevel(linearSampler, uv, 0);
  if (tile.z < (1.0 / 255.0)) return;

  const float2 vel = MBS_DecodeVelocity(velocityTex.SampleLevel(linearSampler, uv, 0).xy);
  const float speed = length(vel);
  if (speed < 1.0) return;

  const float2 dir = vel / speed;
  const float radius = clamp(speed * 0.35, 1.0, 24.0);

  float3 sum = center.rgb;
  float weightSum = 1.0;
  const int TAPS = 4;
  [unroll] for (int i = 1; i <= TAPS; i++)
  {
    const float t = float(i) / float(TAPS);
    const float2 offset = dir * (radius * t) * invSize;
    const float falloff = exp(-2.0 * t * t);
    [unroll] for (int side = -1; side <= 1; side += 2)
    {
      const float2 sampleUV = uv + offset * side;
      const float3 c = colorTex.SampleLevel(linearSampler, sampleUV, 0).rgb;
      const float sampleSpeed = length(MBS_DecodeVelocity(velocityTex.SampleLevel(linearSampler, sampleUV, 0).xy));
      const float similarity = saturate(1.0 - abs(sampleSpeed - speed) / max(speed, 1.0));
      const float weight = falloff * similarity;
      sum += c * weight;
      weightSum += weight;
    }
  }

  const float3 smoothed = sum / weightSum;
  o0.rgb = smoothed;
}
