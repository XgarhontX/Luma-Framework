// ---- Created with 3Dmigoto v1.3.16 on Sat Aug 09 22:01:31 2025

SamplerState g_sampler_s : register(s0);
Texture2D<float4> g_texture : register(t0);

Texture2D<float4> prev_texture : register(t1); // CUSTOM_PS4BLUR_1

cbuffer Quad : register(b0) // bound though unused
{
  float4 g_texcoord_modifier : packoffset(c0);
  float4 g_texel_size : packoffset(c1);
  float4 g_color : packoffset(c2);
  float4 g_texture_lod : packoffset(c3);
}

// 3Dmigoto declarations
#define cmp -
#include "./common1.hlsl"

float3 Saturation(float3 x, float s) {
  x = UCSTo(x, CS_BT709);
  x.yz *= s;
  x = UCSFrom(x, CS_BT709);
  x = max(0, x); //clamp cs
  return x;
}

void main(
  float4 v0 : SV_POSITION0,
  float4 v1 : TEXCOORD0,
  out float4 o0 : SV_Target0
#if CUSTOM_PS4BLUR_1 > 0
  , out float3 o1 : SV_Target1 //r11b11g10f
#endif
)
{
  o0.xyzw = g_texture.Sample(g_sampler_s, v1.xy).xyzw;
  o0.w = saturate(o0.w); // unorm

  float3 x = o0.xyz;
  x = max(0, x);
  #if CUSTOM_TESTSDR == 1
    x = min(x, 1); // unorm
  #endif

  #if CUSTOM_PS4BLUR_1 > 0
    o1.xyz = x; // save to prev
    float3 prev = prev_texture.Sample(g_sampler_s, v1.xy).xyz; // load prev

    #if CUSTOM_PS4BLUR_1 == 1 // lerp ghosting
      x = lerp(x, prev, 0.2); // lerp //TODO: very close, but verify exact value from code... somewhere?
    #elif CUSTOM_PS4BLUR_1 == 2 // horizontal interlacing
      float2 texSize = g_texel_size.zw;
      bool isEvenFrame = LumaSettings.FrameIndex % 2 == 0;
      bool isEvenRow = floor(v1.y * texSize.y) % 2 == 0; 
      if ((isEvenFrame && isEvenRow) || (!isEvenFrame && !isEvenRow)) {
        // noop
      } else {
        x = prev;
      }
    #endif
  #endif

  #if CUSTOM_TESTSDR == 1
    o0.xyz = x;
    return;
  #endif

  // intermediate decode
  x = DecodeIntermediate(x);
  
  // Saturation
  #if CUSTOM_COLORGRADE_SATORDER == 1 || CUSTOM_ALTSAT == 1
    float s = 1;
    #if CUSTOM_ALTSAT == 0
      s *= GS.CGSaturation;
    #endif
    #if CUSTOM_ALTSAT == 1
      x = 1.f;
    #endif
    x = Saturation(x, GS.CGSaturation);
  #endif

  // intermediate scaling
  x *= GS.IntermediateScalingCached;

  // intermediate encode
  x = EncodeIntermediate(x);

  o0.xyz = x;
  return;
}