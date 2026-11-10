// dof_gather_tile0
// ---- Created with 3Dmigoto v1.3.16 on Tue Sep 02 15:46:09 2025

SamplerState g_sampler_s : register(s0);
Texture2D<float2> g_tile : register(t0); // 192x108 (so 0.1 * 1920x1080) (always, regardless full res)
// g_tile: linear depth and blur factor


// 3Dmigoto declarations
#define cmp -

// bias/expand tiles
void main(
  float4 v0 : SV_POSITION0,
  float4 v1 : TEXCOORD0,
  out float2 o0 : SV_Target0)
{
  float4 r0,r1,r2,r3;
  uint4 bitmask, uiDest;
  float4 fDest;

  // debug skip expand
  #if 0
    o0.xy = g_tile.SampleLevel(g_sampler_s, v1.zw, 0).xy; 
    return;
  #endif

  // texel size
  g_tile.GetDimensions(0, uiDest.x, uiDest.y, uiDest.z);
  r0.xy = uiDest.xy;
  r0.xy = (uint2)r0.xy;
  r0.xy = float2(1,1) / r0.xy;

  // 1
  r1.xy = -r0.xy;
  r2.xy = v1.zw + r1.xy;
  r2.xy = g_tile.SampleLevel(g_sampler_s, r2.xy, 0).xy; // x: linear depth, y: blur factor

  // 2
  r1.z = 0;
  r1.xyzw = v1.zwzw + r1.zyxz;
  r1.xy = g_tile.SampleLevel(g_sampler_s, r1.xy, 0).xy;
  r1.zw = g_tile.SampleLevel(g_sampler_s, r1.zw, 0).xy;

  // 
  r1.x = min(r2.x, r1.x); // take min linear depth
  r1.y = max(r2.y, r1.y); // take max blur factor

  // 3 & 4
  r0.z = -r0.y; 
  r2.xyzw = v1.zwzw + r0.xzxy;
  r2.xy = g_tile.SampleLevel(g_sampler_s, r2.xy, 0).xy;
  r2.zw = g_tile.SampleLevel(g_sampler_s, r2.zw, 0).xy;
  r0.z = min(r2.x, r1.x);
  r1.x = max(r2.y, r1.y);

  r1.x = max(r1.x, r1.w);
  r0.z = min(r0.z, r1.z);

  // 5
  r1.yz = g_tile.SampleLevel(g_sampler_s, v1.zw, 0).xy;
  r0.z = min(r1.y, r0.z);
  r1.x = max(r1.x, r1.z);

  // 6, 7, 8
  r0.w = 0;
  r3.xyzw = v1.zwzw + r0.xwwy;
  r0.xy = r0.xy * float2(-1,1) + v1.zw;
  r0.xy = g_tile.SampleLevel(g_sampler_s, r0.xy, 0).xy;
  r1.yz = g_tile.SampleLevel(g_sampler_s, r3.xy, 0).xy;
  r2.xy = g_tile.SampleLevel(g_sampler_s, r3.zw, 0).xy;
  r0.z = min(r1.y, r0.z);
  r0.w = max(r1.x, r1.z);
  r0.y = max(r0.w, r0.y);
  r0.x = min(r0.z, r0.x);
  r0.x = min(r0.x, r2.x);
  r0.y = max(r0.y, r2.y);

  o0.y = max(r0.y, r2.w);
  o0.x = min(r0.x, r2.z);
  return;
}