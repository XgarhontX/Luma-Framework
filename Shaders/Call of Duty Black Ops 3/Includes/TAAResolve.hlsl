#ifndef LUMA_CODBO3_TAA_RESOLVE_HLSL
#define LUMA_CODBO3_TAA_RESOLVE_HLSL

static const float TAA_HISTORY_WEIGHT = 0.9;
static const float TAA_VARIANCE_GAMMA = 1.0;
static const float TAA_RESPONSIVENESS = 0.6;
static const float TAA_MOTION_REJECTION = 0.5;

float2 TAA_DecodeVelocity(float2 e)
{
  float2 a = abs(e);
  float2 px = (a <= 0.5) ? (a * 20.0) : (10.0 + (a - 0.5) * 60.0);
  return sign(e) * px;
}

float3 TAA_RGBToYCoCg(float3 c)
{
  return float3(0.25 * c.r + 0.5 * c.g + 0.25 * c.b, 0.5 * c.r - 0.5 * c.b, -0.25 * c.r + 0.5 * c.g - 0.25 * c.b);
}

float3 TAA_YCoCgToRGB(float3 c)
{
  return float3(c.x + c.y - c.z, c.x + c.z, c.x - c.y - c.z);
}

float TAA_EncodeLuma(float3 c)
{
  return dot(sqrt(max(c, 0.0) * 3.0517578125e-05), float3(0.2126, 0.7152, 0.0722));
}

float3 TAA_SampleHistory(Texture2D<float4> historyTex, SamplerState samp, float2 uv, float2 texSize, float2 invTexSize)
{
  float2 samplePos = uv * texSize;
  float2 texPos1 = floor(samplePos - 0.5) + 0.5;
  float2 f = samplePos - texPos1;
  float2 w0 = f * (-0.5 + f * (1.0 - 0.5 * f));
  float2 w1 = 1.0 + f * f * (-2.5 + 1.5 * f);
  float2 w2 = f * (0.5 + f * (2.0 - 1.5 * f));
  float2 w3 = f * f * (-0.5 + 0.5 * f);
  float2 w12 = w1 + w2;
  float2 offset12 = w2 / w12;
  float2 texPos0 = (texPos1 - 1.0) * invTexSize;
  float2 texPos3 = (texPos1 + 2.0) * invTexSize;
  float2 texPos12 = (texPos1 + offset12) * invTexSize;
  float3 result = 0.0;
  result += historyTex.SampleLevel(samp, float2(texPos12.x, texPos0.y), 0).rgb * (w12.x * w0.y);
  result += historyTex.SampleLevel(samp, float2(texPos0.x, texPos12.y), 0).rgb * (w0.x * w12.y);
  result += historyTex.SampleLevel(samp, float2(texPos12.x, texPos12.y), 0).rgb * (w12.x * w12.y);
  result += historyTex.SampleLevel(samp, float2(texPos3.x, texPos12.y), 0).rgb * (w3.x * w12.y);
  result += historyTex.SampleLevel(samp, float2(texPos12.x, texPos3.y), 0).rgb * (w12.x * w3.y);
  return max(result, 0.0);
}

float3 TAA_ClipAABB(float3 boxMin, float3 boxMax, float3 history, out float clipAmount)
{
  float3 center = 0.5 * (boxMax + boxMin);
  float3 extents = 0.5 * (boxMax - boxMin) + 1e-5;
  float3 v = history - center;
  float3 a = abs(v / extents);
  float ma = max(a.x, max(a.y, a.z));
  clipAmount = max(ma - 1.0, 0.0);
  return (ma > 1.0) ? (center + v / ma) : history;
}

void TAA_NeighbourhoodBox(Texture2D<float4> colorTex, SamplerState samp, float2 uvCur, float2 px, float3 cY, out float3 boxMin, out float3 boxMax)
{
  float3 m1 = cY;
  float3 m2 = cY * cY;
  float3 nMin = cY;
  float3 nMax = cY;
  [unroll] for (int y = -1; y <= 1; y++)
  {
    [unroll] for (int x = -1; x <= 1; x++)
    {
      if (x == 0 && y == 0) continue;
      float3 n = TAA_RGBToYCoCg(max(colorTex.SampleLevel(samp, uvCur + float2(x, y) * px, 0).rgb, 0.0));
      m1 += n;
      m2 += n * n;
      nMin = min(nMin, n);
      nMax = max(nMax, n);
    }
  }
  const float3 mean = m1 / 9.0;
  const float3 sigma = sqrt(max(m2 / 9.0 - mean * mean, 0.0));
  boxMin = max(mean - TAA_VARIANCE_GAMMA * sigma, nMin);
  boxMax = min(mean + TAA_VARIANCE_GAMMA * sigma, nMax);
  boxMin = min(boxMin, cY);
  boxMax = max(boxMax, cY);
}

float2 TAA_DilateVelocityUV(Texture2D<float4> depthTex, SamplerState samp, float2 uv, float2 px)
{
  float2 velUV = uv;
  float bestDepth = depthTex.SampleLevel(samp, uv, 0).x;
  [unroll] for (int y = -1; y <= 1; y++)
  {
    [unroll] for (int x = -1; x <= 1; x++)
    {
      if (x == 0 && y == 0) continue;
      float2 tapUV = uv + float2(x, y) * px;
      float d = depthTex.SampleLevel(samp, tapUV, 0).x;
      if (d > bestDepth) { bestDepth = d; velUV = tapUV; }
    }
  }
  return velUV;
}

struct TAAResult
{
  float3 color;
  float lumaCurrent;
  float lumaHistory;
  float2 reprojUV;
  float2 velocity;
};

TAAResult TAA_Resolve(Texture2D<float4> colorTex, Texture2D<float4> historyTex, Texture2D<float4> lumaTex1, Texture2D<float4> lumaTex2, Texture2D<float4> lumaTex3,
  Texture2D<float4> velTex0, Texture2D<float4> velTex1, Texture2D<float4> depthTex, SamplerState samp,
  float2 uv, float2 jitterCur, float2 jitterHist, float2 rtSize, float2 px, bool useLumaTex2)
{
  TAAResult r;
  const float2 uvCur = uv + jitterCur;

  float3 c = max(colorTex.SampleLevel(samp, uvCur, 0).rgb, 0.0);
  r.lumaCurrent = TAA_EncodeLuma(c);
  float3 cY = TAA_RGBToYCoCg(c);
  float3 boxMin, boxMax;
  TAA_NeighbourhoodBox(colorTex, samp, uvCur, px, cY, boxMin, boxMax);

  const float2 velUV = TAA_DilateVelocityUV(depthTex, samp, uv, px);
  const float2 d0 = TAA_DecodeVelocity(velTex0.SampleLevel(samp, velUV, 0).xy);
  const float2 reprojUV = uv - d0 * px;
  const float2 d1 = TAA_DecodeVelocity(velTex1.SampleLevel(samp, reprojUV, 0).xy);
  r.reprojUV = reprojUV;
  r.velocity = d0;

  const float2 histUV = reprojUV + jitterHist;
  r.lumaHistory = TAA_EncodeLuma(historyTex.SampleLevel(samp, histUV, 0).rgb);
  float3 hY = TAA_RGBToYCoCg(TAA_SampleHistory(historyTex, samp, histUV, rtSize, px));
  float clipAmount;
  float3 hClipped = TAA_ClipAABB(boxMin, boxMax, hY, clipAmount);

  float w = TAA_HISTORY_WEIGHT;
  w *= saturate(1.0 - clipAmount * (2.0 * TAA_RESPONSIVENESS));
  {
    float speed = sqrt(max(dot(d0, d0), dot(d1, d1)));
    float consistency = saturate(1.0 - 0.25 * length(d0 - d1));
    float reject = min(saturate(40.0 - speed), consistency * consistency);
    w *= lerp(1.0, reject, TAA_MOTION_REJECTION);
  }
  {
    float2 reproj2UV = reprojUV - d1 * px;
    float4 g3 = lumaTex3.GatherRed(samp, reproj2UV - 2.0 * d1 * px + d0 * px);
    float4 g1 = lumaTex1.GatherRed(samp, reprojUV);
    float conf = saturate(1.0 - dot(abs(g1 - g3), float4(10.0, 10.0, 10.0, 10.0)));
    if (useLumaTex2)
      conf = min(conf, saturate(1.0 - 40.0 * abs(r.lumaCurrent - lumaTex2.SampleLevel(samp, reproj2UV, 0).x)));
    w *= lerp(0.5, 1.0, conf);
  }
  if (any(reprojUV < 0.0) || any(reprojUV > 1.0)) w = 0.0;

  float wc = (1.0 - w) / (1.0 + cY.x);
  float wh = w / (1.0 + hClipped.x);
  float3 resultY = (cY * wc + hClipped * wh) / max(wc + wh, 1e-5);
  r.color = max(TAA_YCoCgToRGB(resultY), 0.0);
  return r;
}

void TAA_FilmicWorkQueueAppend(Texture2D<float4> filmicHistoryTex, RWStructuredBuffer<uint2> queue, SamplerState samp,
  float2 pixelPos, float2 uv, float2 reprojUV, float2 velocityPx, float lumaCurrent, float lumaHistory, float2 rtSize, float2 px)
{
  const float2 centreVec = float2(uv.x * 1.5 - 0.75, uv.y * 1.1 - 0.495);
  const float centreWeight = saturate(1.0 - length(centreVec));
  const float lumaFilmic = TAA_EncodeLuma(filmicHistoryTex.SampleLevel(samp, reprojUV, 0).rgb);
  const float weight = saturate(centreWeight * 6.66666651 * max(abs(lumaFilmic - lumaHistory), abs(lumaFilmic - lumaCurrent)) - 0.333333343);
  if (min(saturate(40.0 - length(velocityPx)), weight) <= 0.0) return;

  const float2 samplePos = reprojUV * rtSize;
  const float2 texPos1 = floor(samplePos - 0.5) + 0.5;
  const float2 t = samplePos - texPos1;
  const float2 t2 = t * t;
  const float2 A = -t2 * t + (t2 * 2.0 - t);
  const float2 C = -t2 * t + (t * t + t);
  const float2 D = t2 * t - t2;
  const float2 B = (t2 * t - 2.0 * t2 + 1.0) + C;
  const float2 pos0 = (texPos1 - 1.0) * px;
  const float2 pos3 = (texPos1 + 2.0) * px;
  const float2 pos12 = (texPos1 + C / B) * px;
  float3 s = 0.0;
  s += filmicHistoryTex.SampleLevel(samp, float2(pos0.x, pos0.y), 0).rgb * (A.x * A.y);
  s += filmicHistoryTex.SampleLevel(samp, float2(pos12.x, pos0.y), 0).rgb * (B.x * A.y);
  s += filmicHistoryTex.SampleLevel(samp, float2(pos3.x, pos0.y), 0).rgb * (D.x * A.y);
  s += filmicHistoryTex.SampleLevel(samp, float2(pos0.x, pos12.y), 0).rgb * (A.x * B.y);
  s += filmicHistoryTex.SampleLevel(samp, float2(pos12.x, pos12.y), 0).rgb * (B.x * B.y);
  s += filmicHistoryTex.SampleLevel(samp, float2(pos3.x, pos12.y), 0).rgb * (D.x * B.y);
  s += filmicHistoryTex.SampleLevel(samp, float2(pos0.x, pos3.y), 0).rgb * (A.x * D.y);
  s += filmicHistoryTex.SampleLevel(samp, float2(pos12.x, pos3.y), 0).rgb * (B.x * D.y);
  s += filmicHistoryTex.SampleLevel(samp, float2(pos3.x, pos3.y), 0).rgb * (D.x * D.y);

  const uint fr = f32tof16(s.r);
  const uint fg = f32tof16(s.g);
  const uint fb = f32tof16(s.b);
  uint2 entry;
  entry.x = ((fb << 17) & 0xFFC00000u) | ((((fr >> 4) & 0x7FFu) + ((fg << 7) & 0x3FF800u)) & 0x3FFFFFu);
  entry.y = uint(int(pixelPos.x)) | (uint(int(pixelPos.y)) << 12) | (uint(weight * 255.0) << 24);
  const uint index = queue.IncrementCounter();
  queue[index] = entry;
}

#endif
