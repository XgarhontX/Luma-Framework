#pragma once

#include <atomic>
#include <cstdint>

namespace AOCompute
{
   constexpr uint32_t PS_GTAO_ULTRA = 0x04ED8F94;
   constexpr uint32_t PS_GTAO_HIGH = 0x312EC494;
   constexpr uint32_t PS_GTAO_MEDIUM = 0x0211EB8F;
   constexpr uint32_t PS_DENOISE_ULTRA = 0x8FC85155;
   constexpr uint32_t PS_DENOISE_HIGH = 0x6A8BE686;
   constexpr uint32_t PS_DENOISE_MEDIUM = 0xC4A6CBAF;

   struct OwnedTarget
   {
      D3D11_TEXTURE2D_DESC desc = {};
      ComPtr<ID3D11Texture2D> tex;
      ComPtr<ID3D11UnorderedAccessView> uav;
      void Reset() { desc = {}; tex.reset(); uav.reset(); }
   };

   struct GameTargetUAV
   {
      ID3D11Texture2D* key = nullptr;
      ComPtr<ID3D11Texture2D> tex;
      ComPtr<ID3D11UnorderedAccessView> uav;
      void Reset() { key = nullptr; tex.reset(); uav.reset(); }
   };

   struct State
   {
      OwnedTarget owned_raw;
      OwnedTarget owned_denoised;
      GameTargetUAV game_raw;
      GameTargetUAV game_denoised;
      bool drawn_gtao = false, drawn_gtao_prev = false;
      bool drawn_denoise = false, drawn_denoise_prev = false;
      bool direct_uav_raw = false, direct_uav_denoised = false;
      uint32_t last_width = 0, last_height = 0;
      uint32_t last_gtao_ps = 0, last_denoise_ps = 0;
      uint32_t failures = 0;
      void OnPresent()
      {
         drawn_gtao_prev = drawn_gtao; drawn_gtao = false;
         drawn_denoise_prev = drawn_denoise; drawn_denoise = false;
      }
      void Reset()
      {
         owned_raw.Reset(); owned_denoised.Reset(); game_raw.Reset(); game_denoised.Reset();
      }
   };

   inline bool IsGTAO(uint32_t ps) { return ps == PS_GTAO_ULTRA || ps == PS_GTAO_HIGH || ps == PS_GTAO_MEDIUM; }
   inline bool IsDenoise(uint32_t ps) { return ps == PS_DENOISE_ULTRA || ps == PS_DENOISE_HIGH || ps == PS_DENOISE_MEDIUM; }

   inline uint32_t ShaderNameHash(uint32_t ps)
   {
      switch (ps)
      {
      case PS_GTAO_ULTRA: return CompileTimeStringHash("CoDBO3 GTAO Ultra CS");
      case PS_GTAO_HIGH: return CompileTimeStringHash("CoDBO3 GTAO High CS");
      case PS_GTAO_MEDIUM: return CompileTimeStringHash("CoDBO3 GTAO Medium CS");
      case PS_DENOISE_ULTRA: return CompileTimeStringHash("CoDBO3 GTAO Denoise Ultra CS");
      case PS_DENOISE_HIGH: return CompileTimeStringHash("CoDBO3 GTAO Denoise High CS");
      case PS_DENOISE_MEDIUM: return CompileTimeStringHash("CoDBO3 GTAO Denoise Medium CS");
      }
      return 0;
   }

   inline void RegisterNativeShaders()
   {
      using reshade::api::pipeline_subobject_type;
      native_shaders_definitions.emplace(CompileTimeStringHash("CoDBO3 GTAO Ultra CS"), ShaderDefinition{ "Luma_CoDBO3_AOCompute", pipeline_subobject_type::compute_shader, nullptr, "gtao_cs", { { "GTAO_SLICES", "6" } } });
      native_shaders_definitions.emplace(CompileTimeStringHash("CoDBO3 GTAO High CS"), ShaderDefinition{ "Luma_CoDBO3_AOCompute", pipeline_subobject_type::compute_shader, nullptr, "gtao_cs", { { "GTAO_SLICES", "2" } } });
      native_shaders_definitions.emplace(CompileTimeStringHash("CoDBO3 GTAO Medium CS"), ShaderDefinition{ "Luma_CoDBO3_AOCompute", pipeline_subobject_type::compute_shader, nullptr, "gtao_cs", { { "GTAO_SLICES", "1" } } });
      native_shaders_definitions.emplace(CompileTimeStringHash("CoDBO3 GTAO Denoise Ultra CS"), ShaderDefinition{ "Luma_CoDBO3_AOCompute", pipeline_subobject_type::compute_shader, nullptr, "denoise_cs", { { "AO_DENOISE_VARIANT", "0" } } });
      native_shaders_definitions.emplace(CompileTimeStringHash("CoDBO3 GTAO Denoise High CS"), ShaderDefinition{ "Luma_CoDBO3_AOCompute", pipeline_subobject_type::compute_shader, nullptr, "denoise_cs", { { "AO_DENOISE_VARIANT", "1" } } });
      native_shaders_definitions.emplace(CompileTimeStringHash("CoDBO3 GTAO Denoise Medium CS"), ShaderDefinition{ "Luma_CoDBO3_AOCompute", pipeline_subobject_type::compute_shader, nullptr, "denoise_cs", { { "AO_DENOISE_VARIANT", "2" } } });
   }

   namespace
   {
      DXGI_FORMAT UAVFormat(DXGI_FORMAT tex_format, DXGI_FORMAT rtv_format)
      {
         switch (tex_format)
         {
         case DXGI_FORMAT_R8_TYPELESS: return rtv_format == DXGI_FORMAT_UNKNOWN ? DXGI_FORMAT_R8_UNORM : rtv_format;
         case DXGI_FORMAT_R16_TYPELESS: return rtv_format == DXGI_FORMAT_UNKNOWN ? DXGI_FORMAT_R16_UNORM : rtv_format;
         case DXGI_FORMAT_R32_TYPELESS: return rtv_format == DXGI_FORMAT_UNKNOWN ? DXGI_FORMAT_R32_FLOAT : rtv_format;
         case DXGI_FORMAT_R8G8_TYPELESS: return rtv_format == DXGI_FORMAT_UNKNOWN ? DXGI_FORMAT_R8G8_UNORM : rtv_format;
         case DXGI_FORMAT_R8G8B8A8_TYPELESS: return rtv_format == DXGI_FORMAT_UNKNOWN ? DXGI_FORMAT_R8G8B8A8_UNORM : rtv_format;
         case DXGI_FORMAT_R16G16B16A16_TYPELESS: return rtv_format == DXGI_FORMAT_UNKNOWN ? DXGI_FORMAT_R16G16B16A16_FLOAT : rtv_format;
         case DXGI_FORMAT_R8_UNORM: case DXGI_FORMAT_R8_UINT: case DXGI_FORMAT_R8_SNORM:
         case DXGI_FORMAT_R16_UNORM: case DXGI_FORMAT_R16_FLOAT: case DXGI_FORMAT_R16_SNORM:
         case DXGI_FORMAT_R32_FLOAT: case DXGI_FORMAT_R8G8_UNORM: case DXGI_FORMAT_R16G16_FLOAT: case DXGI_FORMAT_R16G16_UNORM:
         case DXGI_FORMAT_R8G8B8A8_UNORM: case DXGI_FORMAT_R16G16B16A16_FLOAT: case DXGI_FORMAT_R11G11B10_FLOAT: case DXGI_FORMAT_R10G10B10A2_UNORM:
            return tex_format;
         default: return DXGI_FORMAT_UNKNOWN;
         }
      }

      ID3D11UnorderedAccessView* ResolveOutput(ID3D11Device* device, ID3D11Texture2D* game_tex, const D3D11_TEXTURE2D_DESC& game_desc, DXGI_FORMAT rtv_format, GameTargetUAV& game_cache, OwnedTarget& owned, bool& direct)
      {
         const DXGI_FORMAT uav_format = UAVFormat(game_desc.Format, rtv_format);
         if (uav_format == DXGI_FORMAT_UNKNOWN) return nullptr;

         D3D11_UNORDERED_ACCESS_VIEW_DESC uav_desc = {};
         uav_desc.Format = uav_format;
         uav_desc.ViewDimension = D3D11_UAV_DIMENSION_TEXTURE2D;
         uav_desc.Texture2D.MipSlice = 0;

         if ((game_desc.BindFlags & D3D11_BIND_UNORDERED_ACCESS) != 0)
         {
            direct = true;
            if (game_cache.key != game_tex || !game_cache.uav.get())
            {
               game_cache.Reset();
               ComPtr<ID3D11UnorderedAccessView> uav;
               if (FAILED(device->CreateUnorderedAccessView(game_tex, &uav_desc, uav.put()))) return nullptr;
               game_cache.key = game_tex;
               game_cache.tex = game_tex;
               game_cache.uav = uav;
            }
            return game_cache.uav.get();
         }

         direct = false;
         if (!owned.tex.get() || owned.desc.Width != game_desc.Width || owned.desc.Height != game_desc.Height || owned.desc.Format != game_desc.Format)
         {
            owned.Reset();
            D3D11_TEXTURE2D_DESC desc = game_desc;
            desc.MipLevels = 1;
            desc.ArraySize = 1;
            desc.SampleDesc = { 1, 0 };
            desc.Usage = D3D11_USAGE_DEFAULT;
            desc.BindFlags = D3D11_BIND_UNORDERED_ACCESS | D3D11_BIND_SHADER_RESOURCE;
            desc.CPUAccessFlags = 0;
            desc.MiscFlags = 0;
            if (FAILED(device->CreateTexture2D(&desc, nullptr, owned.tex.put()))) { owned.Reset(); return nullptr; }
            if (FAILED(device->CreateUnorderedAccessView(owned.tex.get(), &uav_desc, owned.uav.put()))) { owned.Reset(); return nullptr; }
            owned.desc = desc;
         }
         return owned.uav.get();
      }
   }

   inline bool OnDraw(ID3D11Device* device, ID3D11DeviceContext* ctx, DeviceData& device_data, State& state, uint32_t ps)
   {
      const bool is_gtao = IsGTAO(ps);
      if (!is_gtao && !IsDenoise(ps)) return false;

      auto cs_it = device_data.native_compute_shaders.find(ShaderNameHash(ps));
      if (cs_it == device_data.native_compute_shaders.end() || !cs_it->second.get()) { state.failures++; return false; }

      ComPtr<ID3D11RenderTargetView> rtv;
      ComPtr<ID3D11DepthStencilView> dsv;
      ctx->OMGetRenderTargets(1, rtv.put(), dsv.put());
      if (!rtv.get()) { state.failures++; return false; }
      ComPtr<ID3D11Resource> rt_res;
      rtv->GetResource(rt_res.put());
      ComPtr<ID3D11Texture2D> rt_tex;
      if (!rt_res.get() || FAILED(rt_res->QueryInterface(rt_tex.put()))) { state.failures++; return false; }
      D3D11_TEXTURE2D_DESC rt_desc;
      rt_tex->GetDesc(&rt_desc);
      D3D11_RENDER_TARGET_VIEW_DESC rtv_desc;
      rtv->GetDesc(&rtv_desc);
      if (rt_desc.SampleDesc.Count != 1 || rtv_desc.ViewDimension != D3D11_RTV_DIMENSION_TEXTURE2D || rtv_desc.Texture2D.MipSlice != 0) { state.failures++; return false; }

      bool direct = false;
      ID3D11UnorderedAccessView* uav = ResolveOutput(device, rt_tex.get(), rt_desc, rtv_desc.Format, is_gtao ? state.game_raw : state.game_denoised, is_gtao ? state.owned_raw : state.owned_denoised, direct);
      if (!uav) { state.failures++; return false; }

      std::array<ID3D11ShaderResourceView*, 8> srvs = {};
      ctx->PSGetShaderResources(0, UINT(srvs.size()), srvs.data());
      std::array<ID3D11Buffer*, 9> cbs = {};
      ctx->PSGetConstantBuffers(0, UINT(cbs.size()), cbs.data());
      ID3D11SamplerState* sampler = nullptr;
      ctx->PSGetSamplers(0, 1, &sampler);

      std::array<ID3D11RenderTargetView*, D3D11_SIMULTANEOUS_RENDER_TARGET_COUNT> bound_rtvs = {};
      ID3D11DepthStencilView* bound_dsv = nullptr;
      ctx->OMGetRenderTargets(UINT(bound_rtvs.size()), bound_rtvs.data(), &bound_dsv);
      ctx->OMSetRenderTargets(0, nullptr, nullptr);

      DrawStateStack<DrawStateStackType::Compute> cs_state;
      cs_state.Cache(ctx, device_data.uav_max_count);

      ctx->CSSetShaderResources(0, UINT(srvs.size()), srvs.data());
      ctx->CSSetConstantBuffers(0, UINT(cbs.size()), cbs.data());
      if (device_data.luma_global_settings.get())
      {
         ID3D11Buffer* luma_cb = device_data.luma_global_settings.get();
         ctx->CSSetConstantBuffers(luma_settings_cbuffer_index, 1, &luma_cb);
      }
      ctx->CSSetSamplers(0, 1, &sampler);
      UINT initial_count = UINT(-1);
      ctx->CSSetUnorderedAccessViews(0, 1, &uav, &initial_count);
      ctx->CSSetShader(cs_it->second.get(), nullptr, 0);
      ctx->Dispatch((rt_desc.Width + 7) / 8, (rt_desc.Height + 7) / 8, 1);

      ID3D11UnorderedAccessView* null_uav = nullptr;
      ctx->CSSetUnorderedAccessViews(0, 1, &null_uav, nullptr);
      cs_state.Restore(ctx);

      if (!direct)
      {
         OwnedTarget& owned = is_gtao ? state.owned_raw : state.owned_denoised;
         ctx->CopyResource(rt_tex.get(), owned.tex.get());
      }

      ctx->OMSetRenderTargets(UINT(bound_rtvs.size()), bound_rtvs.data(), bound_dsv);
      for (auto* v : bound_rtvs) if (v) v->Release();
      if (bound_dsv) bound_dsv->Release();
      for (auto* v : srvs) if (v) v->Release();
      for (auto* b : cbs) if (b) b->Release();
      if (sampler) sampler->Release();

      if (is_gtao) { state.drawn_gtao = true; state.direct_uav_raw = direct; state.last_gtao_ps = ps; }
      else { state.drawn_denoise = true; state.direct_uav_denoised = direct; state.last_denoise_ps = ps; }
      state.last_width = rt_desc.Width;
      state.last_height = rt_desc.Height;
      return true;
   }
}
