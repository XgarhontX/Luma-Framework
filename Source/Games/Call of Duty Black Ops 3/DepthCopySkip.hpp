#pragma once

#include <cstdint>

namespace DepthCopySkip
{
   constexpr bool enabled = true;

   struct Tracker
   {
      ID3D11Resource* depth = nullptr;
      ID3D11Resource* last_dst = nullptr;
      bool dirty = true;
      bool armed = false;
      uint32_t copies_frame = 0, skipped_frame = 0, partial_frame = 0;
      uint32_t copies_prev = 0, skipped_prev = 0, partial_prev = 0;
      uint32_t total_skipped = 0;
      D3D11_TEXTURE2D_DESC depth_desc = {};
   };
   inline Tracker tracker;

   inline bool IsDepthStencilTexture(ID3D11Resource* res, D3D11_TEXTURE2D_DESC* out_desc = nullptr)
   {
      if (!res) return false;
      ComPtr<ID3D11Texture2D> tex;
      if (FAILED(res->QueryInterface(tex.put())) || !tex.get()) return false;
      D3D11_TEXTURE2D_DESC desc;
      tex->GetDesc(&desc);
      if ((desc.BindFlags & D3D11_BIND_DEPTH_STENCIL) == 0) return false;
      if (out_desc) *out_desc = desc;
      return true;
   }

   inline void MarkDirty() { tracker.dirty = true; tracker.armed = false; }

   inline bool OnCopy(ID3D11Resource* dst, ID3D11Resource* src, bool full_copy)
   {
      if (!dst || !src) return false;
      if (dst == tracker.depth) { MarkDirty(); return false; }
      D3D11_TEXTURE2D_DESC desc;
      if (!IsDepthStencilTexture(src, &desc)) return false;

      if (!full_copy) { tracker.partial_frame++; return false; }
      tracker.copies_frame++;
      if (enabled && tracker.depth == src && tracker.last_dst == dst && !tracker.dirty)
      {
         tracker.skipped_frame++;
         tracker.total_skipped++;
         return true;
      }
      tracker.depth = src;
      tracker.last_dst = dst;
      tracker.depth_desc = desc;
      tracker.dirty = false;
      tracker.armed = true;
      return false;
   }

   inline void OnDrawOrDispatch(ID3D11DeviceContext* ctx, bool is_dispatch)
   {
      if (!tracker.armed || tracker.dirty) return;
      if (is_dispatch)
      {
         std::array<ID3D11UnorderedAccessView*, D3D11_PS_CS_UAV_REGISTER_COUNT> uavs = {};
         ctx->CSGetUnorderedAccessViews(0, UINT(uavs.size()), uavs.data());
         for (auto* uav : uavs)
         {
            if (!uav) continue;
            ComPtr<ID3D11Resource> res;
            uav->GetResource(res.put());
            if (res.get() == tracker.depth) MarkDirty();
            uav->Release();
         }
         return;
      }
      ComPtr<ID3D11DepthStencilView> dsv;
      ctx->OMGetRenderTargets(0, nullptr, dsv.put());
      if (!dsv.get()) return;
      ComPtr<ID3D11Resource> res;
      dsv->GetResource(res.put());
      if (res.get() != tracker.depth) return;
      D3D11_DEPTH_STENCIL_VIEW_DESC dsv_desc;
      dsv->GetDesc(&dsv_desc);
      const bool depth_read_only = (dsv_desc.Flags & D3D11_DSV_READ_ONLY_DEPTH) != 0;
      const bool stencil_read_only = (dsv_desc.Flags & D3D11_DSV_READ_ONLY_STENCIL) != 0;
      if (depth_read_only && stencil_read_only) return;
      ComPtr<ID3D11DepthStencilState> dss;
      UINT stencil_ref = 0;
      ctx->OMGetDepthStencilState(dss.put(), &stencil_ref);
      D3D11_DEPTH_STENCIL_DESC dss_desc;
      if (dss.get()) dss->GetDesc(&dss_desc);
      else { dss_desc = CD3D11_DEPTH_STENCIL_DESC(CD3D11_DEFAULT()); }
      const bool depth_writes = !depth_read_only && dss_desc.DepthEnable && dss_desc.DepthWriteMask == D3D11_DEPTH_WRITE_MASK_ALL;
      auto face_writes = [](const D3D11_DEPTH_STENCILOP_DESC& f) { return f.StencilFailOp != D3D11_STENCIL_OP_KEEP || f.StencilDepthFailOp != D3D11_STENCIL_OP_KEEP || f.StencilPassOp != D3D11_STENCIL_OP_KEEP; };
      const bool stencil_writes = !stencil_read_only && dss_desc.StencilEnable && dss_desc.StencilWriteMask != 0 && (face_writes(dss_desc.FrontFace) || face_writes(dss_desc.BackFace));
      if (depth_writes || stencil_writes) MarkDirty();
   }

   inline void OnClearDepthStencil(ID3D11Resource* res)
   {
      if (res && res == tracker.depth) MarkDirty();
   }

   inline void OnPresent()
   {
      tracker.copies_prev = tracker.copies_frame; tracker.copies_frame = 0;
      tracker.skipped_prev = tracker.skipped_frame; tracker.skipped_frame = 0;
      tracker.partial_prev = tracker.partial_frame; tracker.partial_frame = 0;
      tracker.depth = nullptr;
      tracker.last_dst = nullptr;
      tracker.dirty = true;
      tracker.armed = false;
   }
}
