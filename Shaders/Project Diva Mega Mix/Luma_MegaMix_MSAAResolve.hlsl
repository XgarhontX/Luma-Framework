#if CUSTOM_MSAA == 1 // 2x
  #define MSAA_COUNT 2
#elif CUSTOM_MSAA == 2 // 4x
  #define MSAA_COUNT 4
#elif CUSTOM_MSAA == 3 // 8x
  #define MSAA_COUNT 8
#elif CUSTOM_MSAA == 4 // 16x
  #define MSAA_COUNT 16
#else
  #define MSAA_COUNT 0
#endif

Texture2DMS<float> colorMS : register(t0);
Texture2DMS<float> depthMS : register(t1);

void FullDepthMaxToOriginal(float4 pos: SV_Position, out float depth: SV_Depth) // original is not RTV
{
  uint2 pix = uint2(pos.xy);
  depth = depthMS.Load(pix, 0);
  [unroll] for (int i = 1; i < MSAA_COUNT; i++)
  {
    depth = max(depth, depthMS.Load(pix, i)); // pick closest depth (DoF required to not bleed foreground into background)
  }
}
void FullDepthMinToOriginal(float4 pos: SV_Position, out float depth: SV_Depth) // original is not RTV
{
  uint2 pix = uint2(pos.xy);
  depth = depthMS.Load(pix, 0);
  [unroll] for (int i = 1; i < MSAA_COUNT; i++)
  {
    depth = min(depth, depthMS.Load(pix, i)); // pick farthest depth (tells NPR Contour that this pixel is not character, allowing it to draw)
  }
}

void FastDepthToOriginal(float4 pos: SV_Position, out float depth: SV_Depth) // original is not RTV
{
  uint2 pix = uint2(pos.xy);
  depth = depthMS.Load(pix, 0);
}

// mainly for XeGTAO. fast, just take the first sample (since XeGTAO luminance dodge doesn't need precision)
void FastColorAndDepthToOriginal(float4 pos: SV_Position, out float4 color: SV_Target, out float depth: SV_Depth)
{
  uint2 pix = uint2(pos.xy);
  depth = depthMS.Load(pix, 0);
  color = colorMS.Load(pix, 0);
}