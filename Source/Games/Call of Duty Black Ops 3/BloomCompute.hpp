#pragma once

#include <array>
#include <atomic>
#include <cmath>
#include <cstdint>
#include <string>

#include "BloomIdentify.hpp"

namespace BloomCompute
{
   enum class Pass : uint8_t
   {
      DownsampleFirst,
      DownsampleL1,
      DownsampleL1Focus,
      DownsampleL1FocusBloom,
      DownsampleEv,
      BlurY1Final,
      BlurY2,
      BlurY3,
      BlurY4,
      BlurY5,
      GaussX,
      GaussY,
      BlurX1,
      BlurX2,
      BlurX3,
      BlurX4,
      BlurX5,
      Count
   };
   constexpr size_t PASS_COUNT = size_t(Pass::Count);
   constexpr size_t MAX_OUTPUTS = 3;

   constexpr uint32_t NameHash(const char* s)
   {
      uint32_t hash = 0x811c9dc5u;
      for (; *s != '\0'; ++s)
      {
         hash ^= static_cast<uint8_t>(*s);
         hash *= 0x01000193u;
      }
      return hash;
   }

   struct PassInfo
   {
      Pass pass;
      uint32_t ps_hash;
      const char* cs_name;
      const char* cs_entry;
      const char* cs_define;
      const char* cs_define_value;
      uint8_t output_mask;
      bool reads_t1;
      const char* description;
   };

   constexpr PassInfo PASSES[PASS_COUNT] = {
      { Pass::DownsampleFirst,        0x57CF6767, "CoDBO3 Bloom Downsample First",    "cs_downsample_first",          nullptr,            nullptr, 0b001, false, "scene -> bloom level 0 (13 taps, luma weighted)" },
      { Pass::DownsampleL1,           0x6C33E7C6, "CoDBO3 Bloom Downsample L1",       "cs_downsample_l1",             nullptr,            nullptr, 0b101, false, "level 1: exposure (o0) + bloom mip (o2)" },
      { Pass::DownsampleL1Focus,      0x91028930, "CoDBO3 Bloom Downsample L1 Focus", "cs_downsample_l1_focus",       nullptr,            nullptr, 0b011, true,  "level 1: exposure (o0) + focus (o1, t1 depth)" },
      { Pass::DownsampleL1FocusBloom, 0xF76C11FD, "CoDBO3 Bloom Downsample L1 Full",  "cs_downsample_l1_focus_bloom", nullptr,            nullptr, 0b111, true,  "level 1: exposure (o0) + focus (o1) + bloom mip (o2)" },
      { Pass::DownsampleEv,           0x0F5717DC, "CoDBO3 Bloom Downsample EV",       "cs_downsample_ev",             nullptr,            nullptr, 0b001, false, "exposure downsample (o0)" },
      { Pass::BlurY1Final,            0x0741FB20, "CoDBO3 Bloom Blur Y1 Final",       "cs_blur_y",                    "BLOOM_BLUR_LEVEL", "1",     0b001, true,  "vertical blur level 1 + previous level + final composite" },
      { Pass::BlurY2,                 0xCFA9AD8F, "CoDBO3 Bloom Blur Y2",             "cs_blur_y",                    "BLOOM_BLUR_LEVEL", "2",     0b001, true,  "vertical blur level 2 + previous level" },
      { Pass::BlurY3,                 0x21586316, "CoDBO3 Bloom Blur Y3",             "cs_blur_y",                    "BLOOM_BLUR_LEVEL", "3",     0b001, true,  "vertical blur level 3 + previous level" },
      { Pass::BlurY4,                 0x34B12927, "CoDBO3 Bloom Blur Y4",             "cs_blur_y",                    "BLOOM_BLUR_LEVEL", "4",     0b001, true,  "vertical blur level 4 + previous level" },
      { Pass::BlurY5,                 0x2DFFF4F8, "CoDBO3 Bloom Blur Y5",             "cs_blur_y",                    "BLOOM_BLUR_LEVEL", "5",     0b001, false, "vertical blur level 5 (smallest)" },
      { Pass::GaussX,                 0xF1549CBF, "CoDBO3 Bloom Gauss X",             "cs_gauss",                     "BLOOM_GAUSS_AXIS", "0",     0b001, false, "separable gaussian, horizontal" },
      { Pass::GaussY,                 0xFC312583, "CoDBO3 Bloom Gauss Y",             "cs_gauss",                     "BLOOM_GAUSS_AXIS", "1",     0b001, false, "separable gaussian, vertical" },
      { Pass::BlurX1,                 0,          "CoDBO3 Bloom Blur X1",             "cs_blur_x",                    "BLOOM_BLUR_LEVEL", "1",     0b001, false, "horizontal blur level 1 (7 taps)" },
      { Pass::BlurX2,                 0,          "CoDBO3 Bloom Blur X2",             "cs_blur_x",                    "BLOOM_BLUR_LEVEL", "2",     0b001, false, "horizontal blur level 2 (9 taps)" },
      { Pass::BlurX3,                 0,          "CoDBO3 Bloom Blur X3",             "cs_blur_x",                    "BLOOM_BLUR_LEVEL", "3",     0b001, false, "horizontal blur level 3 (11 taps)" },
      { Pass::BlurX4,                 0,          "CoDBO3 Bloom Blur X4",             "cs_blur_x",                    "BLOOM_BLUR_LEVEL", "4",     0b001, false, "horizontal blur level 4 (13 taps)" },
      { Pass::BlurX5,                 0,          "CoDBO3 Bloom Blur X5",             "cs_blur_x",                    "BLOOM_BLUR_LEVEL", "5",     0b001, false, "horizontal blur level 5 (15 taps)" },
   };

   inline std::atomic<uint32_t> detected_hashes[PASS_COUNT] = {};

   inline const PassInfo* FindPass(uint32_t ps_hash)
   {
      if (ps_hash == 0) return nullptr;
      for (size_t i = 0; i < PASS_COUNT; i++)
      {
         const PassInfo& p = PASSES[i];
         const uint32_t hash = p.ps_hash != 0 ? p.ps_hash : detected_hashes[i].load(std::memory_order_relaxed);
         if (hash == ps_hash) return &p;
      }
      return nullptr;
   }

   inline void IdentifyShader(const std::byte* code, size_t size, reshade::api::pipeline_subobject_type type, uint32_t shader_hash)
   {
      if (type != reshade::api::pipeline_subobject_type::pixel_shader || code == nullptr || size < 16 || (size % 4) != 0 || shader_hash == 0) return;
      uint32_t sample_ops = 0;
      const uint32_t level = DetectBlurXLevel(reinterpret_cast<const uint32_t*>(code), size / 4, &sample_ops);
      if (level == 0) return;
      const size_t pass_index = size_t(Pass::BlurX1) + (level - 1);
      uint32_t expected = 0;
      if (detected_hashes[pass_index].compare_exchange_strong(expected, shader_hash) || expected == shader_hash)
      {
         reshade::log::message(reshade::log::level::info, std::format("BloomCompute: pixel shader {:08X} identified as bloom horizontal mip blur level {} ({} taps)", shader_hash, level, sample_ops).c_str());
      }
      else
      {
         reshade::log::message(reshade::log::level::warning, std::format("BloomCompute: pixel shader {:08X} also looks like bloom horizontal mip blur level {} (already {:08X}), ignored", shader_hash, level, expected).c_str());
      }
   }

   template<typename DefinitionsMap>
   void RegisterNativeShaders(DefinitionsMap& definitions)
   {
      for (const auto& p : PASSES)
      {
         ShaderDefinition definition{ "Luma_CoDBO3_BloomCS", reshade::api::pipeline_subobject_type::compute_shader, nullptr, p.cs_entry };
         if (p.cs_define != nullptr)
            definition.defines_data.push_back({ p.cs_define, p.cs_define_value });
         definitions.emplace(NameHash(p.cs_name), std::move(definition));
      }
   }

   struct alignas(16) Constants
   {
      float out_size[4];
      float lod0;
      float lod1;
      float pad[2];
   };
   static_assert(sizeof(Constants) == 32);

   struct OutputTarget
   {
      ComPtr<ID3D11Resource> game_resource;
      UINT game_subresource = 0;
      bool direct = false;
      ComPtr<ID3D11UnorderedAccessView> uav;
      ComPtr<ID3D11Texture2D> scratch;
      D3D11_TEXTURE2D_DESC scratch_desc = {};
      DXGI_FORMAT view_format = DXGI_FORMAT_UNKNOWN;

      void Reset()
      {
         game_resource.reset();
         game_subresource = 0;
         direct = false;
         uav.reset();
         scratch.reset();
         scratch_desc = {};
         view_format = DXGI_FORMAT_UNKNOWN;
      }
   };

   struct DeviceState
   {
      std::array<std::array<OutputTarget, MAX_OUTPUTS>, PASS_COUNT> outputs;
      ComPtr<ID3D11Buffer> constants;

      std::array<uint8_t, PASS_COUNT> seen = {}, seen_prev = {};
      uint32_t dispatches = 0, dispatches_prev = 0;
      uint32_t direct_outputs = 0, direct_outputs_prev = 0;
      uint32_t copied_outputs = 0, copied_outputs_prev = 0;
      uint32_t fallbacks = 0, fallbacks_prev = 0;
      std::string last_fallback_reason;

      void OnPresent()
      {
         seen_prev = seen; seen.fill(0);
         dispatches_prev = dispatches; dispatches = 0;
         direct_outputs_prev = direct_outputs; direct_outputs = 0;
         copied_outputs_prev = copied_outputs; copied_outputs = 0;
         fallbacks_prev = fallbacks; fallbacks = 0;
      }

      void Reset()
      {
         for (auto& pass_outputs : outputs)
            for (auto& o : pass_outputs) o.Reset();
         constants.reset();
      }
   };

   namespace Detail
   {
      inline DXGI_FORMAT UavFormat(DXGI_FORMAT rtv_format)
      {
         switch (rtv_format)
         {
         case DXGI_FORMAT_R32G32B32A32_FLOAT:
         case DXGI_FORMAT_R16G16B16A16_FLOAT:
         case DXGI_FORMAT_R16G16B16A16_UNORM:
         case DXGI_FORMAT_R32G32_FLOAT:
         case DXGI_FORMAT_R16G16_FLOAT:
         case DXGI_FORMAT_R16G16_UNORM:
         case DXGI_FORMAT_R10G10B10A2_UNORM:
         case DXGI_FORMAT_R11G11B10_FLOAT:
         case DXGI_FORMAT_R8G8B8A8_UNORM:
         case DXGI_FORMAT_R8G8_UNORM:
         case DXGI_FORMAT_R32_FLOAT:
         case DXGI_FORMAT_R16_FLOAT:
         case DXGI_FORMAT_R16_UNORM:
         case DXGI_FORMAT_R8_UNORM:
            return rtv_format;
         default:
            return DXGI_FORMAT_UNKNOWN;
         }
      }

      struct TargetInfo
      {
         ComPtr<ID3D11Resource> resource;
         ComPtr<ID3D11Texture2D> texture;
         D3D11_TEXTURE2D_DESC desc = {};
         D3D11_RENDER_TARGET_VIEW_DESC rtv_desc = {};
         UINT mip = 0;
         UINT slice = 0;
         UINT width = 0, height = 0;
      };

      inline bool GetTargetInfo(ID3D11RenderTargetView* rtv, TargetInfo& info, std::string& reason)
      {
         rtv->GetResource(info.resource.put());
         if (!info.resource || FAILED(info.resource->QueryInterface(info.texture.put()))) { reason = "render target is not a 2D texture"; return false; }
         info.texture->GetDesc(&info.desc);
         rtv->GetDesc(&info.rtv_desc);
         if (info.rtv_desc.ViewDimension == D3D11_RTV_DIMENSION_TEXTURE2D) { info.mip = info.rtv_desc.Texture2D.MipSlice; info.slice = 0; }
         else if (info.rtv_desc.ViewDimension == D3D11_RTV_DIMENSION_TEXTURE2DARRAY && info.rtv_desc.Texture2DArray.ArraySize == 1) { info.mip = info.rtv_desc.Texture2DArray.MipSlice; info.slice = info.rtv_desc.Texture2DArray.FirstArraySlice; }
         else { reason = "unsupported render target view dimension"; return false; }
         if (info.desc.SampleDesc.Count != 1) { reason = "multisampled render target"; return false; }
         info.width = (std::max)(1u, info.desc.Width >> info.mip);
         info.height = (std::max)(1u, info.desc.Height >> info.mip);
         return true;
      }

      inline bool PrepareOutput(ID3D11Device* device, OutputTarget& out, const TargetInfo& info, std::string& reason)
      {
         const DXGI_FORMAT view_format = UavFormat(info.rtv_desc.Format);
         if (view_format == DXGI_FORMAT_UNKNOWN) { reason = std::format("render target format {} has no UAV equivalent", static_cast<uint32_t>(info.rtv_desc.Format)); return false; }
         const UINT subresource = D3D11CalcSubresource(info.mip, info.slice, info.desc.MipLevels);
         const bool can_direct = (info.desc.BindFlags & D3D11_BIND_UNORDERED_ACCESS) != 0;

         if (out.uav && out.direct == can_direct && out.view_format == view_format)
         {
            if (can_direct && out.game_resource.get() == info.resource.get() && out.game_subresource == subresource) return true;
            if (!can_direct && out.scratch && out.scratch_desc.Width == info.width && out.scratch_desc.Height == info.height && out.scratch_desc.Format == info.desc.Format)
            {
               out.game_resource = info.resource;
               out.game_subresource = subresource;
               return true;
            }
         }

         out.Reset();
         out.game_resource = info.resource;
         out.game_subresource = subresource;
         out.direct = can_direct;
         out.view_format = view_format;

         D3D11_UNORDERED_ACCESS_VIEW_DESC uav_desc = {};
         uav_desc.Format = view_format;
         if (can_direct)
         {
            if (info.desc.ArraySize > 1)
            {
               uav_desc.ViewDimension = D3D11_UAV_DIMENSION_TEXTURE2DARRAY;
               uav_desc.Texture2DArray.MipSlice = info.mip;
               uav_desc.Texture2DArray.FirstArraySlice = info.slice;
               uav_desc.Texture2DArray.ArraySize = 1;
            }
            else
            {
               uav_desc.ViewDimension = D3D11_UAV_DIMENSION_TEXTURE2D;
               uav_desc.Texture2D.MipSlice = info.mip;
            }
            if (FAILED(device->CreateUnorderedAccessView(info.texture.get(), &uav_desc, out.uav.put()))) { out.Reset(); reason = "CreateUnorderedAccessView on the game texture failed"; return false; }
            return true;
         }

         out.scratch_desc = info.desc;
         out.scratch_desc.Width = info.width;
         out.scratch_desc.Height = info.height;
         out.scratch_desc.MipLevels = 1;
         out.scratch_desc.ArraySize = 1;
         out.scratch_desc.Usage = D3D11_USAGE_DEFAULT;
         out.scratch_desc.BindFlags = D3D11_BIND_UNORDERED_ACCESS;
         out.scratch_desc.CPUAccessFlags = 0;
         out.scratch_desc.MiscFlags = 0;
         if (FAILED(device->CreateTexture2D(&out.scratch_desc, nullptr, out.scratch.put()))) { out.Reset(); reason = "scratch texture creation failed"; return false; }
         uav_desc.ViewDimension = D3D11_UAV_DIMENSION_TEXTURE2D;
         uav_desc.Texture2D.MipSlice = 0;
         if (FAILED(device->CreateUnorderedAccessView(out.scratch.get(), &uav_desc, out.uav.put()))) { out.Reset(); reason = "scratch UAV creation failed"; return false; }
         return true;
      }

      inline float InputLod(ID3D11ShaderResourceView* srv, UINT out_width, UINT out_height)
      {
         if (srv == nullptr) return 0.f;
         D3D11_SHADER_RESOURCE_VIEW_DESC srv_desc;
         srv->GetDesc(&srv_desc);
         if (srv_desc.ViewDimension != D3D11_SRV_DIMENSION_TEXTURE2D || srv_desc.Texture2D.MipLevels == 1) return 0.f;
         ComPtr<ID3D11Resource> resource;
         srv->GetResource(resource.put());
         ComPtr<ID3D11Texture2D> texture;
         if (!resource || FAILED(resource->QueryInterface(texture.put()))) return 0.f;
         D3D11_TEXTURE2D_DESC desc;
         texture->GetDesc(&desc);
         const UINT mip0 = srv_desc.Texture2D.MostDetailedMip;
         const float in_w = float((std::max)(1u, desc.Width >> mip0));
         const float in_h = float((std::max)(1u, desc.Height >> mip0));
         const float ratio = (std::max)(in_w / float((std::max)(1u, out_width)), in_h / float((std::max)(1u, out_height)));
         return (std::max)(0.f, std::log2(ratio));
      }

      inline bool EnsureConstants(ID3D11Device* device, DeviceState& state)
      {
         if (state.constants) return true;
         D3D11_BUFFER_DESC desc = {};
         desc.ByteWidth = sizeof(Constants);
         desc.Usage = D3D11_USAGE_DYNAMIC;
         desc.BindFlags = D3D11_BIND_CONSTANT_BUFFER;
         desc.CPUAccessFlags = D3D11_CPU_ACCESS_WRITE;
         return SUCCEEDED(device->CreateBuffer(&desc, nullptr, state.constants.put()));
      }
   }

   inline bool OnDraw(ID3D11Device* native_device, ID3D11DeviceContext* native_device_context, DeviceData& device_data, DeviceState& state, uint32_t ps_hash, bool enabled)
   {
      const PassInfo* pass = FindPass(ps_hash);
      if (pass == nullptr) return false;
      const size_t pass_index = size_t(pass->pass);
      state.seen[pass_index] = 1;
      if (!enabled) return false;

      auto fallback = [&](std::string reason) { state.fallbacks++; state.last_fallback_reason = std::format("{}: {}", pass->cs_name, reason); return false; };

      auto cs_it = device_data.native_compute_shaders.find(NameHash(pass->cs_name));
      if (cs_it == device_data.native_compute_shaders.end() || !cs_it->second.get()) return fallback("compute shader not compiled");
      if (!Detail::EnsureConstants(native_device, state)) return fallback("constant buffer creation failed");

      std::array<ComPtr<ID3D11RenderTargetView>, MAX_OUTPUTS> rtvs;
      {
         std::array<ID3D11RenderTargetView*, MAX_OUTPUTS> tmp = {};
         native_device_context->OMGetRenderTargets(MAX_OUTPUTS, tmp.data(), nullptr);
         for (size_t i = 0; i < MAX_OUTPUTS; i++) rtvs[i].attach(tmp[i]);
      }
      std::array<ComPtr<ID3D11ShaderResourceView>, 2> srvs;
      {
         std::array<ID3D11ShaderResourceView*, 2> tmp = {};
         native_device_context->PSGetShaderResources(0, 2, tmp.data());
         for (size_t i = 0; i < 2; i++) srvs[i].attach(tmp[i]);
      }
      ComPtr<ID3D11Buffer> postfx_cb;
      native_device_context->PSGetConstantBuffers(8, 1, postfx_cb.put());
      ComPtr<ID3D11SamplerState> sampler;
      native_device_context->PSGetSamplers(0, 1, sampler.put());

      if (!srvs[0]) return fallback("t0 not bound");
      if (pass->reads_t1 && !srvs[1]) return fallback("t1 not bound");
      if (!postfx_cb) return fallback("b8 (PostFxCBuffer) not bound");
      if (!sampler) return fallback("s0 not bound");

      std::string reason;
      std::array<Detail::TargetInfo, MAX_OUTPUTS> targets;
      UINT width = 0, height = 0;
      for (size_t i = 0; i < MAX_OUTPUTS; i++)
      {
         if ((pass->output_mask & (1u << i)) == 0) continue;
         if (!rtvs[i]) return fallback(std::format("render target {} not bound", i));
         if (!Detail::GetTargetInfo(rtvs[i].get(), targets[i], reason)) return fallback(reason);
         if (width == 0) { width = targets[i].width; height = targets[i].height; }
         else if (width != targets[i].width || height != targets[i].height) return fallback("render targets of different sizes");
      }
      if (width == 0 || height == 0) return fallback("no render target");
      std::array<ID3D11UnorderedAccessView*, MAX_OUTPUTS> uavs = {};
      bool any_scratch = false, any_direct = false;
      for (size_t i = 0; i < MAX_OUTPUTS; i++)
      {
         if ((pass->output_mask & (1u << i)) == 0) continue;
         OutputTarget& out = state.outputs[pass_index][i];
         if (!Detail::PrepareOutput(native_device, out, targets[i], reason)) return fallback(reason);
         uavs[i] = out.uav.get();
         any_scratch |= !out.direct;
         any_direct |= out.direct;
      }

      {
         D3D11_MAPPED_SUBRESOURCE mapped;
         if (FAILED(native_device_context->Map(state.constants.get(), 0, D3D11_MAP_WRITE_DISCARD, 0, &mapped))) return fallback("constant buffer map failed");
         Constants* constants = static_cast<Constants*>(mapped.pData);
         constants->out_size[0] = float(width);
         constants->out_size[1] = float(height);
         constants->out_size[2] = 1.f / float(width);
         constants->out_size[3] = 1.f / float(height);
         constants->lod0 = Detail::InputLod(srvs[0].get(), width, height);
         constants->lod1 = pass->reads_t1 ? Detail::InputLod(srvs[1].get(), width, height) : 0.f;
         constants->pad[0] = constants->pad[1] = 0.f;
         native_device_context->Unmap(state.constants.get(), 0);
      }

      DrawStateStack<DrawStateStackType::Compute> compute_state;
      compute_state.Cache(native_device_context, device_data.uav_max_count);

      std::array<ID3D11RenderTargetView*, D3D11_SIMULTANEOUS_RENDER_TARGET_COUNT> om_rtvs = {};
      ID3D11DepthStencilView* om_dsv = nullptr;
      if (any_direct)
      {
         native_device_context->OMGetRenderTargets(D3D11_SIMULTANEOUS_RENDER_TARGET_COUNT, om_rtvs.data(), &om_dsv);
         native_device_context->OMSetRenderTargets(0, nullptr, nullptr);
      }

      native_device_context->CSSetShader(cs_it->second.get(), nullptr, 0);
      {
         ID3D11Buffer* cbs[1] = { postfx_cb.get() };
         native_device_context->CSSetConstantBuffers(8, 1, cbs);
         cbs[0] = state.constants.get();
         native_device_context->CSSetConstantBuffers(10, 1, cbs);
         if (device_data.luma_global_settings.get() && luma_settings_cbuffer_index < D3D11_COMMONSHADER_CONSTANT_BUFFER_API_SLOT_COUNT)
         {
            cbs[0] = device_data.luma_global_settings.get();
            native_device_context->CSSetConstantBuffers(luma_settings_cbuffer_index, 1, cbs);
         }
         if (device_data.luma_instance_data.get() && luma_data_cbuffer_index < D3D11_COMMONSHADER_CONSTANT_BUFFER_API_SLOT_COUNT)
         {
            cbs[0] = device_data.luma_instance_data.get();
            native_device_context->CSSetConstantBuffers(luma_data_cbuffer_index, 1, cbs);
         }
         ID3D11SamplerState* samplers[1] = { sampler.get() };
         native_device_context->CSSetSamplers(0, 1, samplers);
         ID3D11ShaderResourceView* cs_srvs[2] = { srvs[0].get(), srvs[1].get() };
         native_device_context->CSSetShaderResources(0, 2, cs_srvs);
         native_device_context->CSSetUnorderedAccessViews(0, MAX_OUTPUTS, uavs.data(), nullptr);
      }
      native_device_context->Dispatch((width + 7) / 8, (height + 7) / 8, 1);
      {
         std::array<ID3D11UnorderedAccessView*, MAX_OUTPUTS> nulls = {};
         native_device_context->CSSetUnorderedAccessViews(0, MAX_OUTPUTS, nulls.data(), nullptr);
      }

      for (size_t i = 0; i < MAX_OUTPUTS; i++)
      {
         if ((pass->output_mask & (1u << i)) == 0) continue;
         OutputTarget& out = state.outputs[pass_index][i];
         if (out.direct) { state.direct_outputs++; continue; }
         native_device_context->CopySubresourceRegion(out.game_resource.get(), out.game_subresource, 0, 0, 0, out.scratch.get(), 0, nullptr);
         state.copied_outputs++;
      }

      compute_state.Restore(native_device_context, true, true);
      if (any_direct)
      {
         native_device_context->OMSetRenderTargets(D3D11_SIMULTANEOUS_RENDER_TARGET_COUNT, om_rtvs.data(), om_dsv);
         for (auto* rtv : om_rtvs) if (rtv) rtv->Release();
         if (om_dsv) om_dsv->Release();
      }

      state.dispatches++;
      return true;
   }

   inline void DrawImGuiStatus(const DeviceState& state)
   {
      uint32_t seen = 0;
      for (auto s : state.seen_prev) seen += s;
      if (seen == 0)
      {
         ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(0.75f, 0.75f, 0.75f, 1.f));
         ImGui::Bullet(); ImGui::SameLine(); ImGui::TextWrapped("No bloom pass detected this frame (bloom disabled in the in-game settings, or no scene rendered).");
         ImGui::PopStyleColor();
         return;
      }
      ImGui::PushStyleColor(ImGuiCol_Text, IM_COL32(100, 255, 100, 255));
      ImGui::BulletText("%u bloom passes detected this frame, %u run as compute (%u outputs written directly, %u copied back).", seen, state.dispatches_prev, state.direct_outputs_prev, state.copied_outputs_prev);
      ImGui::PopStyleColor();
      if (state.fallbacks_prev > 0)
      {
         ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(1.f, 0.75f, 0.5f, 1.f));
         ImGui::BulletText("%u bloom draws stayed pixel shaders: %s", state.fallbacks_prev, state.last_fallback_reason.c_str());
         ImGui::PopStyleColor();
      }
      {
         uint32_t identified = 0;
         for (size_t i = size_t(Pass::BlurX1); i <= size_t(Pass::BlurX5); i++) identified += detected_hashes[i].load(std::memory_order_relaxed) != 0 ? 1u : 0u;
         ImGui::PushStyleColor(ImGuiCol_Text, identified == 5 ? IM_COL32(100, 255, 100, 255) : IM_COL32(190, 190, 190, 255));
         ImGui::BulletText("Horizontal mip blur pixel shaders identified at load: %u of 5 (they carry no stable hash, so they are recognised by structure).", identified);
         ImGui::PopStyleColor();
      }
      if (ImGui::TreeNode("Bloom passes seen this frame"))
      {
         for (size_t i = 0; i < PASS_COUNT; i++)
         {
            if (!state.seen_prev[i]) continue;
            ImGui::BulletText("0x%08X %s", PASSES[i].ps_hash != 0 ? PASSES[i].ps_hash : detected_hashes[i].load(std::memory_order_relaxed), PASSES[i].description);
         }
         ImGui::TreePop();
      }
   }
}
