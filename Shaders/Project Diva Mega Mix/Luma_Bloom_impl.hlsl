// Bloom
//

#include "./common1.hlsl"

cbuffer LumaBloom : register(b11)
{
    float2 src_size;
    float2 inv_src_size;
    float2 axis;
    float sigma;
    float tex_noise_index;
}
#define SUGMA sigma

cbuffer Quad : register(b0)
{
  float4 g_texcoord_modifier : packoffset(c0);
  float4 g_texel_size : packoffset(c1);
  float4 g_color : packoffset(c2);
  float4 g_texture_lod : packoffset(c3);
}

SamplerState smp : register(s0);
Texture2D tex : register(t0);


// Fullscreen triangle VS.
void bloom_main_vs(uint vid : SV_VertexID, out float4 pos : SV_Position, out float2 texcoord : TEXCOORD)
{
    texcoord = float2((vid << 1) & 2, vid & 2);
    pos = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}


#define LUMA_BLOOM_THRESHOLD 1.0
#define LUMA_BLOOM_SOFT_KNEE 1.0
float3 quadratic_threshold(float3 color)
{
    const float epsilon = 1e-6;

    // Pixel brightness.
    float br = max(max(color.r, color.g), color.b);
    br = max(epsilon, br);

    // Under the threshold part, a quadratic curve.
    // Above the threshold part will be a linear curve.
    const float k = max(epsilon, LUMA_BLOOM_SOFT_KNEE);
    const float3 curve = float3(LUMA_BLOOM_THRESHOLD - k, k * 2.0, 0.25 / k);
    float rq = clamp(br - curve.x, 0.0, curve.y);
    rq = curve.z * rq * rq;

    // Combine and apply the brightness response curve.
    return color * max(rq, br - LUMA_BLOOM_THRESHOLD) * rcp(br);
}

float get_gaussian_weight(float x, float s)
{
    return exp(-x * x * rcp(2.0 * s * s));
}

float4 bloom_prefilter_ps(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    // Calculate fractional part and texel center.
    const float f = dot(frac(texcoord * src_size - 0.5), axis);
    const float2 tc = texcoord - f * inv_src_size * axis;

    float3 csum = 0.0;
    float wsum = 0.0;

    // Calculate kernel radius.
    const float radius = ceil(SUGMA * 3.0);

    for (float i = 1.0 - radius; i <= radius; ++i) {
        const float weight = get_gaussian_weight(i - f, SUGMA);
        // csum += tex.SampleLevel(smp, tc + i * inv_src_size * axis, 0.0).rgb * weight;
        csum += tex.SampleLevel(smp, tc + i * inv_src_size * axis, 0.0).rgb * weight;
        wsum += weight;
    }

    // Normalize.
    csum *= rcp(wsum);

    // Apply threshold.
    float3 color = /* quadratic_threshold */(csum);

    // boost
    // float y = GetLuminance(color);
    // float y1 = y;
    // y1 = RenoDX_Shadows(y1, DVS1, DVS2);
    // y1 *= DVS3;
    // color *= safeDivision(y1, y, 0);
    // color *= 1.053;
    // color *= 1.088;

    // Threshold
    color -= g_color.xyz;
    color = max(0, color);

    return float4(color, 1.0);
}

float4 bloom_downsample_ps(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    // Calculate fractional part and texel center.
    const float f = dot(frac(texcoord * src_size - 0.5), axis);
    const float2 tc = texcoord - f * inv_src_size * axis;

    float3 csum = 0.0;
    float wsum = 0.0;

    // Calculate kernel radius.
    const float radius = ceil(SUGMA * 3.0);

    for (float i = 1.0 - radius; i <= radius; ++i) {
        const float weight = get_gaussian_weight(i - f, SUGMA);
        csum += tex.SampleLevel(smp, tc + i * inv_src_size * axis, 0.0).rgb * weight;
        wsum += weight;
    }

    // Normalize.
    csum *= rcp(wsum);

    return float4(csum, 1.0);
}

// Bicubic upsampling in 4 texture fetches.
//
// f(x) = (4 + 3 * |x|^3 – 6 * |x|^2) / 6 for 0 <= |x| <= 1
// f(x) = (2 – |x|)^3 / 6 for 1 < |x| <= 2
// f(x) = 0 otherwise
//
// Source: https://www.researchgate.net/publication/220494113_Efficient_GPU-Based_Texture_Interpolation_using_Uniform_B-Splines
float4 bloom_upsample_ps(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    // transform the coordinate from [0,extent] to [-0.5, extent-0.5]
    float2 coord_grid = texcoord * src_size - 0.5;
    float2 index = floor(coord_grid);
    float2 fraction = coord_grid - index;
    float2 one_frac = 1.0 - fraction;
    float2 one_frac2 = one_frac * one_frac;
    float2 fraction2 = fraction * fraction;
    float2 w0 = 1.0 / 6.0 * one_frac2 * one_frac;
    float2 w1 = 2.0 / 3.0 - 0.5 * fraction2 * (2.0 - fraction);
    float2 w2 = 2.0 / 3.0 - 0.5 * one_frac2 * (2.0 - one_frac);
    float2 w3 = 1.0 / 6.0 * fraction2 * fraction;
    float2 g0 = w0 + w1;
    float2 g1 = w2 + w3;

    // h0 = w1/g0 - 1, move from [-0.5, extent-0.5] to [0, extent]
    float2 h0 = (w1 / g0) - 0.5 + index;
    float2 h1 = (w3 / g1) + 1.5 + index;

    // fetch the four linear interpolations
    float3 tex00 = tex.SampleLevel(smp, float2(h0.x, h0.y) * inv_src_size, 0.0).rgb;
    float3 tex10 = tex.SampleLevel(smp, float2(h1.x, h0.y) * inv_src_size, 0.0).rgb;
    float3 tex01 = tex.SampleLevel(smp, float2(h0.x, h1.y) * inv_src_size, 0.0).rgb;
    float3 tex11 = tex.SampleLevel(smp, float2(h1.x, h1.y) * inv_src_size, 0.0).rgb;

    // weigh along the y-direction
    tex00 = lerp(tex01, tex00, g0.y);
    tex10 = lerp(tex11, tex10, g0.y);

    // weigh along the x-direction
    return float4(lerp(tex10, tex00, g0.x), 1.0);
}




// bloom_combine_ps
SamplerState g_sampler_s : register(s0);
Texture2D<float4> g_textures_0_ : register(t0); // 255x144 (1/1)
Texture2D<float4> g_textures_1_ : register(t1); // 128x72  (1/2)
Texture2D<float4> g_textures_2_ : register(t2); // 64x36   (1/4)
Texture2D<float4> g_textures_3_ : register(t3); // 32x18   (1/8)
// out: 255x144

float4 BloomUpsample2(Texture2D tex, SamplerState smp, float2 texcoord, float2 texSize, float2 pixSize) {
  float2 coord_grid = texcoord * texSize - 0.5;
  float2 index = floor(coord_grid);
  float2 fraction = coord_grid - index;
  float2 one_frac = 1.0 - fraction;
  float2 one_frac2 = one_frac * one_frac;
  float2 fraction2 = fraction * fraction;
  float2 w0 = 1.0 / 6.0 * one_frac2 * one_frac;
  float2 w1 = 2.0 / 3.0 - 0.5 * fraction2 * (2.0 - fraction);
  float2 w2 = 2.0 / 3.0 - 0.5 * one_frac2 * (2.0 - one_frac);
  float2 w3 = 1.0 / 6.0 * fraction2 * fraction;
  float2 g0 = w0 + w1;
  float2 g1 = w2 + w3;

  // h0 = w1/g0 - 1, move from [-0.5, extent-0.5] to [0, extent]
  float2 h0 = (w1 / g0) - 0.5 + index;
  float2 h1 = (w3 / g1) + 1.5 + index;

  // fetch the four linear interpolations
  float4 tex00 = tex.SampleLevel(smp, float2(h0.x, h0.y) * pixSize, 0.0).xyzw;
  float4 tex10 = tex.SampleLevel(smp, float2(h1.x, h0.y) * pixSize, 0.0).xyzw;
  float4 tex01 = tex.SampleLevel(smp, float2(h0.x, h1.y) * pixSize, 0.0).xyzw;
  float4 tex11 = tex.SampleLevel(smp, float2(h1.x, h1.y) * pixSize, 0.0).xyzw;

  // weigh along the y-direction
  tex00 = lerp(tex01, tex00, g0.y);
  tex10 = lerp(tex11, tex10, g0.y);

  // weigh along the x-direction
  return lerp(tex10, tex00, g0.x);
}

void bloom_blur0_vs(
  uint v0 : SV_VertexID0,
  out float4 o0 : SV_POSITION0,
  out float4 o1 : TEXCOORD0,
  out float4 o2 : TEXCOORD1,
  out float2 o3 : TEXCOORD2
)
{
  float4 r0;
  uint4 bitmask, uiDest;
  float4 fDest;

  r0.x = (uint)v0.x >> 1;
  r0.x = (uint)r0.x;
  r0.x = r0.x * 2 + -1;
  r0.z = (int)v0.x & 1;
  r0.z = (uint)r0.z;
  r0.y = r0.z * 2 + -1;
  o0.xy = r0.xy;
  r0.xyzw = r0.xyxy * g_texcoord_modifier.xyxy + g_texcoord_modifier.zwzw;
  o0.zw = float2(0,1);

  o1.xyzw = g_texel_size.xyxy * float4(-0.5,-0.5,0.5,-0.5) + r0.zwzw;
  o2.xyzw = g_texel_size.xyxy * float4(-0.5,0.5,0.5,0.5) + r0.xyzw;
  o3.xy = r0.xy; // center
  
  return;
}
void bloom_blur0_ps(
  float4 v0: SV_POSITION0,
  float4 v1: TEXCOORD0,
  float4 v2: TEXCOORD1,
  float2 v3: TEXCOORD2,
  out float4 o0: SV_Target0)
{
  float4 r0,r1;
  uint4 bitmask, uiDest;
  float4 fDest;

  // r0.xyzw = g_textures_0_.Sample(g_sampler_s, v1.xy).xyzw;
  // r1.xyzw = g_textures_0_.Sample(g_sampler_s, v1.zw).xyzw;
  // r0.xyzw = r1.xyzw + r0.xyzw;
  // r1.xyzw = g_textures_0_.Sample(g_sampler_s, v2.xy).xyzw;
  // r0.xyzw = r1.xyzw + r0.xyzw;
  // r1.xyzw = g_textures_0_.Sample(g_sampler_s, v2.zw).xyzw;
  // r0.xyzw = r1.xyzw + r0.xyzw;
  // o0.xyzw = g_color.xyzw * 0.25 * r0.xyzw;

  float4 bloom = BloomUpsample2(g_textures_0_, g_sampler_s, v3.xy, g_texel_size.zw, g_texel_size.xy);
  o0 = g_color * bloom;
}

void bloom_combine_ps(
  float4 v0 : SV_POSITION0,
  float4 v1 : TEXCOORD0,
  float4 v2 : TEXCOORD1,
  float2 v3 : TEXCOORD2,
  out float4 o0 : SV_Target0)
{
  float4 r0,r1;
  uint4 bitmask, uiDest;
  float4 fDest;
  o0.w = 1;

//   uint2 texSize1; 
//   g_textures_1_.GetDimensions(texSize1.x, texSize1.y);
//   float2 texSize2 = texSize1 * 0.5f;
//   float2 texSize3 = texSize2 * 0.5f;
// 
//   float2 pixSize1 = rcp(texSize1);
//   float2 pixSize2 = rcp(texSize2);
//   float2 pixSize3 = rcp(texSize3);
// 
//   float4 b0 = g_textures_0_.Sample(g_sampler_s, v3.xy).xyzw; 
//   float3 b1 = BloomUpsample2(g_textures_1_, g_sampler_s, v3.xy, texSize1, pixSize1);
//   float3 b2 = BloomUpsample2(g_textures_2_, g_sampler_s, v3.xy, texSize2, pixSize2);
//   float3 b3 = BloomUpsample2(g_textures_3_, g_sampler_s, v3.xy, texSize3, pixSize3);

  // float4 b0 = g_textures_0_.Sample(g_sampler_s, v3.xy).xyzw;
  // float3 b1 = g_textures_1_.Sample(g_sampler_s, v3.xy).xyz;
  // float3 b2 = g_textures_2_.Sample(g_sampler_s, v3.xy).xyz;
  // float3 b3 = g_textures_3_.Sample(g_sampler_s, v3.xy).xyz;

  uint2 texSize0;
  g_textures_0_.GetDimensions(texSize0.x, texSize0.y);
  float2 texSize1 = texSize0 * 0.5f;
  float2 texSize2 = texSize1 * 0.5f;
  float2 texSize3 = texSize2 * 0.5f;

  float2 pixSize0 = rcp(texSize0);
  float2 pixSize1 = rcp(texSize1);
  float2 pixSize2 = rcp(texSize2);
  float2 pixSize3 = rcp(texSize3);

  float4 b0 = BloomUpsample2(g_textures_0_, g_sampler_s, v3.xy, texSize0, pixSize0).xyzw;
  float3 b1 = BloomUpsample2(g_textures_1_, g_sampler_s, v3.xy, texSize1, pixSize1).xyz;
  float3 b2 = BloomUpsample2(g_textures_2_, g_sampler_s, v3.xy, texSize2, pixSize2).xyz;
  float3 b3 = BloomUpsample2(g_textures_3_, g_sampler_s, v3.xy, texSize3, pixSize3).xyz;

  o0.w = b0.w;
  o0.xyz =  b0.xyz * (g_color.x * GS.BloomStrengths.x * (1.125 * 1.100 /* * DVS1 */));
  o0.xyz += b1.xyz * (g_color.y * GS.BloomStrengths.y * (1.267 * 1.050 /* * DVS2 */));
  o0.xyz += b2.xyz * (g_color.z * GS.BloomStrengths.z * (1.287 * 1.000 /* * DVS3 */));
  o0.xyz += b3.xyz * (g_color.w * GS.BloomStrengths.w * (1.300 * 1.000 /* * DVS4 */));

//   o0 = b0; //debug

  o0.xyz *= GS.BloomStrength /* * 1.3325 */;

  return;
}