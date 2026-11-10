// dof_f2_downsample
// ---- Created with 3Dmigoto v1.3.16 on Tue Sep 02 15:46:05 2025

cbuffer PsCommon : register(b0)
{
  float4 g_depth_params : packoffset(c0);
  float4 g_spread_scale : packoffset(c1);
  float4 g_depth_params2 : packoffset(c2); // x: focal plane, y: aperture width, z: aperture shape, w: strength
  float4 g_texcoord_offset_for_upsample : packoffset(c3);
  int4 g_dof_param : packoffset(c4);

// g_depth_params 19.99983, 0.00017, 0.00, 0.00 (0 float4)
// g_spread_scale 27193.05664, 9064.35254, 0.33333, 3.00 (16 float4)
// g_depth_params2 3.76145, 1.59632, -0.01329, 2.26034 (32 float4)
// g_texcoord_offset_for_upsample 0.00078, 0.00139, 0.00078, 0.00139 (48 float4)
// g_dof_param 20, 8, 7, 8 (64 int4)
}

SamplerState g_depth_sampler_s : register(s0);
SamplerState g_color_sampler_s : register(s1);
Texture2D<float> g_depth : register(t0); // full res
Texture2D<float4> g_color : register(t1); // full res


// 3Dmigoto declarations
#define cmp -

// https://www.desmos.com/calculator/eudc3yupeo
float CalculateBlurFactor(float linearDepth, float4 params)
{
  float blur = params.x - linearDepth;
  blur = -params.y + abs(blur);
  blur = max(0, blur);
  blur = blur * blur;
  blur = params.z * blur;
  blur = 1.44269502 * blur;
  blur = exp2(blur);
  blur = 1 - blur;
  blur = params.w * blur;
  return blur;
}

// 0.5x downsample color
// and spread scale calcuation (CoC stuff?)
void main(
  float4 v0 : SV_POSITION0,
  float4 v1 : TEXCOORD0,
  // r11g11b10f (bruh, they use this here but not anywhere else?)
  out float3 o0 : SV_Target0, // downsample 0.5x color (g_color)
  out float3 o1 : SV_Target1 // x: blurred downsampled color, y: 0, z:  (g_presort)
)
{
  // kernel texcoord offsets, forms diamond pattern https://www.desmos.com/calculator/cyn6ok0dor
  const float4 icb[] = { { 0.000781, 0, 0.000781, 0},
                         { 0.000241, -0.001321, 0, -0.001389},
                         { 0.000241, 0.001321, -0.000781, 0},
                         { -0.000632, -0.000816, 0, 0.001389},
                         { -0.000632, 0.000816, 0.000781, 0},
                         { -0.000552, -0.000982, -0.000241, -0.001203}, // start of max quality offsets (xy)
                         { 0, -0.001389, -0.000241, 0.001203},
                         { 0.000552, -0.000982, 0, 0},
                         { -0.000781, 0, 0, 0},
                         { 0.000781, 0, 0, 0},
                         { -0.000552, 0.000982, 0, 0},
                         { 0, 0.001389, 0, 0},
                         { 0.000552, 0.000982, 0, 0} };
  float4 r0,r1,r2,r3,r4;
  uint4 bitmask, uiDest;
  float4 fDest;
  o1.y = 0; // bruh

  // depth center (min of 4 samples)
  float4 depthCenterGather = g_depth.Gather(g_depth_sampler_s, v1.xy);
  float depthCenter = min(depthCenterGather.x, min(depthCenterGather.y, min(depthCenterGather.z, depthCenterGather.w)));
  float depthCenterLinear = rcp(depthCenter * g_depth_params.x + g_depth_params.y);

  // blur factor
  float blurFactor = CalculateBlurFactor(depthCenterLinear, g_depth_params2);
  float blurFactorForOffset = 0.333333343 * blurFactor;

  // make use of o1.y, storing blur factor
  {
    // float depthCenterMax = max(depthCenterGather.x, max(depthCenterGather.y, max(depthCenterGather.z, depthCenterGather.w)));
    // float depthCenterMaxLinear = rcp(depthCenterMax * g_depth_params.x + g_depth_params.y);
    // o1.y = CalculateBlurFactor(depthCenterMaxLinear, g_depth_params2);
    o1.y = blurFactor; // min is pretty much same as max
  }

  // loop init: center color
  float3 aColor = g_color.SampleLevel(g_color_sampler_s, v1.xy, 0).xyz;
  float aWeight = 1;

  // loop (screw it, highest quality 8-tap)
  [unroll] for (int i = 0; i < 8; i++)
  {
    // texcoord offset (based on kernel & blur factor) https://www.desmos.com/calculator/cyn6ok0dor
    float2 texCoordCurr = icb[i + 5].xy * blurFactorForOffset + v1.xy;

    // depth at current texcoord
    float4 depthGather = g_depth.Gather(g_depth_sampler_s, texCoordCurr);
    float depth = min(depthGather.x, min(depthGather.y, min(depthGather.z, depthGather.w)));
    float depthLinear = rcp(depth * g_depth_params.x + g_depth_params.y);

    // weight based on depth difference
    float delta = abs(depthLinear - depthCenterLinear);
    float weight = 1 / (1 + delta);

    // accumulate
    aColor += g_color.SampleLevel(g_color_sampler_s, texCoordCurr, 0).xyz * weight;
    aWeight += weight;
  }

  // o0: weighted avg color
  float3 finalColor = aColor / aWeight;
  finalColor = pow(abs(finalColor), 2.2); // gamma decode (linearize)
  o0.xyz = finalColor;

  // o1: blur factor encoded incomplete radius precompute
  float blurFactorEncoded = blurFactor * blurFactor;
  blurFactorEncoded = max(0.5, blurFactorEncoded);
  blurFactorEncoded *= 3.14159274;
  blurFactorEncoded = rcp(blurFactorEncoded);
  o1.z = blurFactorEncoded;

  o1.x = g_spread_scale.z * blurFactor; // raw blur factor * some settings fudge scaler

//   // depth center
//   r0.xyzw = g_depth.Gather(g_depth_sampler_s, v1.xy).xyzw;
//   r0.xy = min(r0.xz, r0.yw);
//   r0.x = min(r0.x, r0.y);
// 
//   // linearize depth center
//   r0.x = r0.x * g_depth_params.x + g_depth_params.y;
//   r0.x = 1 / r0.x;
// 
//   // blur factor
//   r0.y = CalculateBlurFactor(r0.x, g_depth_params2);
// 
//   r0.z = 0.333333343 * r0.y; // fudge factor for later sample radius
// 
//   // center color
//   r1.xyz = g_color.SampleLevel(g_color_sampler_s, v1.xy, 0).xyz;
// 
//   if (cmp((int)g_dof_param.y == 5) != 0) { // BRUHHHH, this is quality level!?!?!
//     r2.xyz = r1.xyz;
//     r0.w = 1;
//     r1.w = 0;
//     while (true) {
//       if (cmp((int)r1.w >= 5) != 0) break;
//       r3.xy = icb[r1.w+0].xy * r0.zz + v1.xy;
//       r4.xyzw = g_depth.Gather(g_depth_sampler_s, r3.xy).xyzw;
//       r4.xyzw = r4.xyzw * g_depth_params.xxxx + g_depth_params.yyyy;
//       r4.xyzw = float4(1,1,1,1) / r4.xyzw;
//       r4.xyzw = r4.xyzw + -r0.xxxx;
//       r3.zw = max(abs(r4.xz), abs(r4.yw));
//       r2.w = max(r3.z, r3.w);
//       r2.w = 1 + r2.w;
//       r2.w = 1 / r2.w;
//       r3.xyz = g_color.SampleLevel(g_color_sampler_s, r3.xy, 0).xyz;
//       r2.xyz = r3.xyz * r2.www + r2.xyz;
//       r0.w = r2.w + r0.w;
//       r1.w = (int)r1.w + 1;
//     }
//   } else {
//     if (cmp((int)g_dof_param.y == 4) != 0) {
//       r2.xyz = r1.xyz;
//       r0.w = 1;
//       r1.w = 0;
//       while (true) {
//         r2.w = cmp((int)r1.w >= 4);
//         if (r2.w != 0) break;
//         r3.xy = icb[r1.w+0].zw * r0.zz + v1.xy;
//         r4.xyzw = g_depth.Gather(g_depth_sampler_s, r3.xy).xyzw;
//         r4.xyzw = r4.xyzw * g_depth_params.xxxx + g_depth_params.yyyy;
//         r4.xyzw = float4(1,1,1,1) / r4.xyzw;
//         r4.xyzw = r4.xyzw + -r0.xxxx;
//         r3.zw = max(abs(r4.xz), abs(r4.yw));
//         r2.w = max(r3.z, r3.w);
//         r2.w = 1 + r2.w;
//         r2.w = 1 / r2.w;
//         r3.xyz = g_color.SampleLevel(g_color_sampler_s, r3.xy, 0).xyz;
//         r2.xyz = r3.xyz * r2.www + r2.xyz;
//         r0.w = r2.w + r0.w;
//         r1.w = (int)r1.w + 1;
//       }
//     } else {
//       if (cmp((int)g_dof_param.y == 3) != 0) {
//         r2.xyz = r1.xyz;
//         r0.w = 1;
//         r1.w = 0;
//         while (true) {
//           if (cmp((int)r1.w >= 3) != 0) break;
//           r3.xy = icb[r1.w+4].zw * r0.zz + v1.xy;
//           r4.xyzw = g_depth.Gather(g_depth_sampler_s, r3.xy).xyzw;
//           r4.xyzw = r4.xyzw * g_depth_params.xxxx + g_depth_params.yyyy;
//           r4.xyzw = float4(1,1,1,1) / r4.xyzw;
//           r4.xyzw = r4.xyzw + -r0.xxxx;
//           r3.zw = max(abs(r4.xz), abs(r4.yw));
//           r2.w = max(r3.z, r3.w);
//           r2.w = 1 + r2.w;
//           r2.w = 1 / r2.w;
//           r3.xyz = g_color.SampleLevel(g_color_sampler_s, r3.xy, 0).xyz;
//           r2.xyz = r3.xyz * r2.www + r2.xyz;
//           r0.w = r2.w + r0.w;
//           r1.w = (int)r1.w + 1;
//         }
//       } else {
//         r2.xyz = r1.xyz;
//         r0.w = 1;
//         r1.w = 0;
//         while (true) {
//           if (cmp((int)r1.w >= 8) != 0) break;
//           r3.xy = icb[r1.w+5].xy * r0.zz + v1.xy;
//           r4.xyzw = g_depth.Gather(g_depth_sampler_s, r3.xy).xyzw;
//           r4.xyzw = r4.xyzw * g_depth_params.xxxx + g_depth_params.yyyy;
//           r4.xyzw = float4(1,1,1,1) / r4.xyzw;
//           r4.xyzw = r4.xyzw + -r0.xxxx;
//           r3.zw = max(abs(r4.xz), abs(r4.yw));
//           r2.w = max(r3.z, r3.w);
//           r2.w = 1 + r2.w;
//           r2.w = 1 / r2.w;
//           r3.xyz = g_color.SampleLevel(g_color_sampler_s, r3.xy, 0).xyz;
//           r2.xyz = r3.xyz * r2.www + r2.xyz;
//           r0.w = r2.w + r0.w;
//           r1.w = (int)r1.w + 1;
//         }
//       }
//     }
//   }
// 
// //   // max quality (7-tap) (g_dof_param.y == 8)
// //   r2.xyz = r1.xyz; // color accumulator
// //   r0.w = 1; // initial weight
// //   r1.w = 0; // loop counter
// //   while (true) {
// //     if (cmp((int)r1.w >= 8) != 0) break; // max iterations
// // 
// //     // texcoord offset (based on kernel & blur factor)
// //     r3.xy = icb[(int)r1.w + 5].xy * r0.z + v1.xy;
// // 
// //     // depth at current texcoord
// //     r4.xyzw = g_depth.Gather(g_depth_sampler_s, r3.xy).xyzw;
// // 
// //     // depth linearize
// //     r4.xyzw = r4.xyzw * g_depth_params.xxxx + g_depth_params.yyyy;
// //     r4.xyzw = float4(1,1,1,1) / r4.xyzw;
// // 
// //     // weight based on depth difference
// //     r4.xyzw -= r0.xxxx; // delta from center depth
// //     r3.zw = max(abs(r4.xz), abs(r4.yw)); // abs
// //     r2.w = max(r3.z, r3.w); // choose high delta
// //     r2.w = 1 / (1 + r2.w); // curved rational function falloff, y(0) = 1
// // 
// //     // color at current texcoord
// //     r3.xyz = g_color.SampleLevel(g_color_sampler_s, r3.xy, 0).xyz;
// //     r2.xyz = r3.xyz * r2.www + r2.xyz; // accumulate weighted color
// //     r0.w = r2.w + r0.w; // accumulate total weight
// //     r1.w = (int)r1.w + 1;
// //   }
// 
//   // total color / total weight
//   r0.xzw = r2.xyz / r0.w;
//   o0.xyz = pow(abs(r0.xzw), 2.2); // gamma decode (linearize)
// 
//   // blur factor, 
//   r0.x = r0.y * r0.y; // sqr
//   r0.x = max(0.5, r0.x); // min blur factor
//   r0.x = 3.14159274 * r0.x; // radius in radians
//   o1.z = 1 / r0.x; // inverse
// 
//   o1.x = g_spread_scale.z * r0.y; // raw blur factor * some settings scaler
  
  return;
}