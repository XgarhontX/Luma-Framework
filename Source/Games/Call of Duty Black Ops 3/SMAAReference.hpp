#pragma once

#include <array>
#include <atomic>
#include <cstdint>
#include <cstring>

namespace SMAAReference
{
   constexpr bool enabled = true;
   constexpr int subsample_mode = 0;
   inline std::atomic<uint32_t> replaced_frames{ 0 };
   inline std::atomic<uint32_t> skipped_dispatches{ 0 };
   inline bool last_frame_in_place = false;
   inline uint32_t last_width = 0, last_height = 0;

   constexpr std::array<uint32_t, 4> SMAA_1X_COMPUTE_HASHES = { 0x6240554C, 0xB037D915, 0x3B3C41EF, 0xCDEFC09A };
   constexpr bool IsSMAA1xHash(uint32_t cs_hash)
   {
      for (uint32_t h : SMAA_1X_COMPUTE_HASHES) if (h == cs_hash) return true;
      return false;
   }

   constexpr uint32_t CS_EDGE_DETECTION = CompileTimeStringHash("CoDBO3 SMAA Edge Detection CS");
   constexpr uint32_t CS_BLENDING_WEIGHTS = CompileTimeStringHash("CoDBO3 SMAA Blending Weight Calculation CS");
   constexpr uint32_t CS_NEIGHBORHOOD_BLENDING = CompileTimeStringHash("CoDBO3 SMAA Neighborhood Blending CS");

   inline void AddNativeShaderDefinitions(std::unordered_map<uint32_t, ShaderDefinition>& native_shaders_definitions)
   {
      native_shaders_definitions.emplace(CS_EDGE_DETECTION, ShaderDefinition{ "Luma_CoDBO3_SMAA", reshade::api::pipeline_subobject_type::compute_shader, nullptr, "smaa_edge_detection_cs" });
      native_shaders_definitions.emplace(CS_BLENDING_WEIGHTS, ShaderDefinition{ "Luma_CoDBO3_SMAA", reshade::api::pipeline_subobject_type::compute_shader, nullptr, "smaa_blending_weight_calculation_cs" });
      native_shaders_definitions.emplace(CS_NEIGHBORHOOD_BLENDING, ShaderDefinition{ "Luma_CoDBO3_SMAA", reshade::api::pipeline_subobject_type::compute_shader, nullptr, "smaa_neighborhood_blending_cs" });
   }

   struct Constants
   {
      float rt_metrics[4];
      float subsample_indices[4];
   };

   struct Resources
   {
      ComPtr<ID3D11Texture2D> area_tex;
      ComPtr<ID3D11ShaderResourceView> area_srv;
      ComPtr<ID3D11Texture2D> search_tex;
      ComPtr<ID3D11ShaderResourceView> search_srv;
      ComPtr<ID3D11Buffer> constants;
      ComPtr<ID3D11SamplerState> sampler_linear;
      ComPtr<ID3D11SamplerState> sampler_point;
      uint32_t width = 0, height = 0;
      ComPtr<ID3D11Texture2D> edges_tex;
      ComPtr<ID3D11UnorderedAccessView> edges_uav;
      ComPtr<ID3D11ShaderResourceView> edges_srv;
      ComPtr<ID3D11Texture2D> blend_tex;
      ComPtr<ID3D11UnorderedAccessView> blend_uav;
      ComPtr<ID3D11ShaderResourceView> blend_srv;
      D3D11_TEXTURE2D_DESC color_copy_desc = {};
      DXGI_FORMAT color_copy_srv_format = DXGI_FORMAT_UNKNOWN;
      ComPtr<ID3D11Texture2D> color_copy_tex;
      ComPtr<ID3D11ShaderResourceView> color_copy_srv;

      bool pass1_seen = false;
      bool replaced = false;
      uint32_t frame_parity = 0;
      ComPtr<ID3D11ShaderResourceView> luma_srv;
      ComPtr<ID3D11ShaderResourceView> color_srv;

      void ResetFrame()
      {
         pass1_seen = false;
         replaced = false;
         luma_srv.reset();
         color_srv.reset();
      }
      void Reset()
      {
         ResetFrame();
         area_tex.reset(); area_srv.reset(); search_tex.reset(); search_srv.reset(); constants.reset(); sampler_linear.reset(); sampler_point.reset();
         width = height = 0;
         edges_tex.reset(); edges_uav.reset(); edges_srv.reset(); blend_tex.reset(); blend_uav.reset(); blend_srv.reset();
         color_copy_desc = {}; color_copy_srv_format = DXGI_FORMAT_UNKNOWN; color_copy_tex.reset(); color_copy_srv.reset();
      }
   };

   namespace
   {
      enum class Role { None, EdgeDetection, QueueResolve, Blending };

      Role DetectRole(ID3D11DeviceContext* ctx)
      {
         std::array<ID3D11UnorderedAccessView*, 8> uavs = {};
         ctx->CSGetUnorderedAccessViews(0, uint32_t(uavs.size()), uavs.data());
         bool is_tex[8] = {}, is_buf[8] = {};
         for (size_t i = 0; i < uavs.size(); i++)
         {
            if (!uavs[i]) continue;
            D3D11_UNORDERED_ACCESS_VIEW_DESC desc;
            uavs[i]->GetDesc(&desc);
            is_tex[i] = desc.ViewDimension == D3D11_UAV_DIMENSION_TEXTURE2D;
            is_buf[i] = desc.ViewDimension == D3D11_UAV_DIMENSION_BUFFER;
            uavs[i]->Release();
         }
         if (is_tex[1] && is_buf[4] && is_buf[5] && !is_tex[2]) return Role::EdgeDetection;
         if (is_tex[2] && (is_buf[4] || is_buf[5]) && !is_tex[1]) return Role::Blending;
         if (is_buf[0] && (is_buf[4] || is_buf[5]) && !is_buf[6] && !is_tex[1] && !is_tex[2] && !is_tex[3]) return Role::QueueResolve;
         return Role::None;
      }

      bool CreateStatic(ID3D11Device* device, Resources& r)
      {
         if (!r.area_srv)
         {
            D3D11_TEXTURE2D_DESC desc = {};
            desc.Width = AREATEX_WIDTH; desc.Height = AREATEX_HEIGHT; desc.MipLevels = 1; desc.ArraySize = 1;
            desc.Format = DXGI_FORMAT_R8G8_UNORM; desc.SampleDesc.Count = 1; desc.Usage = D3D11_USAGE_IMMUTABLE; desc.BindFlags = D3D11_BIND_SHADER_RESOURCE;
            D3D11_SUBRESOURCE_DATA data = {}; data.pSysMem = areaTexBytes; data.SysMemPitch = AREATEX_PITCH;
            if (FAILED(device->CreateTexture2D(&desc, &data, r.area_tex.put()))) return false;
            if (FAILED(device->CreateShaderResourceView(r.area_tex.get(), nullptr, r.area_srv.put()))) return false;
         }
         if (!r.search_srv)
         {
            D3D11_TEXTURE2D_DESC desc = {};
            desc.Width = SEARCHTEX_WIDTH; desc.Height = SEARCHTEX_HEIGHT; desc.MipLevels = 1; desc.ArraySize = 1;
            desc.Format = DXGI_FORMAT_R8_UNORM; desc.SampleDesc.Count = 1; desc.Usage = D3D11_USAGE_IMMUTABLE; desc.BindFlags = D3D11_BIND_SHADER_RESOURCE;
            D3D11_SUBRESOURCE_DATA data = {}; data.pSysMem = searchTexBytes; data.SysMemPitch = SEARCHTEX_PITCH;
            if (FAILED(device->CreateTexture2D(&desc, &data, r.search_tex.put()))) return false;
            if (FAILED(device->CreateShaderResourceView(r.search_tex.get(), nullptr, r.search_srv.put()))) return false;
         }
         if (!r.constants)
         {
            D3D11_BUFFER_DESC desc = {};
            desc.ByteWidth = sizeof(Constants); desc.Usage = D3D11_USAGE_DEFAULT; desc.BindFlags = D3D11_BIND_CONSTANT_BUFFER;
            if (FAILED(device->CreateBuffer(&desc, nullptr, r.constants.put()))) return false;
         }
         if (!r.sampler_linear || !r.sampler_point)
         {
            D3D11_SAMPLER_DESC desc = {};
            desc.Filter = D3D11_FILTER_MIN_MAG_LINEAR_MIP_POINT;
            desc.AddressU = desc.AddressV = desc.AddressW = D3D11_TEXTURE_ADDRESS_CLAMP;
            desc.MaxLOD = D3D11_FLOAT32_MAX;
            if (FAILED(device->CreateSamplerState(&desc, r.sampler_linear.put()))) return false;
            desc.Filter = D3D11_FILTER_MIN_MAG_MIP_POINT;
            if (FAILED(device->CreateSamplerState(&desc, r.sampler_point.put()))) return false;
         }
         return true;
      }

      bool CreateSized(ID3D11Device* device, Resources& r, uint32_t width, uint32_t height)
      {
         if (r.width == width && r.height == height && r.edges_uav && r.blend_uav) return true;
         r.edges_tex.reset(); r.edges_uav.reset(); r.edges_srv.reset(); r.blend_tex.reset(); r.blend_uav.reset(); r.blend_srv.reset();
         r.width = r.height = 0;
         D3D11_TEXTURE2D_DESC desc = {};
         desc.Width = width; desc.Height = height; desc.MipLevels = 1; desc.ArraySize = 1; desc.SampleDesc.Count = 1;
         desc.Usage = D3D11_USAGE_DEFAULT; desc.BindFlags = D3D11_BIND_SHADER_RESOURCE | D3D11_BIND_UNORDERED_ACCESS;
         desc.Format = DXGI_FORMAT_R8G8_UNORM;
         if (FAILED(device->CreateTexture2D(&desc, nullptr, r.edges_tex.put()))) return false;
         if (FAILED(device->CreateUnorderedAccessView(r.edges_tex.get(), nullptr, r.edges_uav.put()))) return false;
         if (FAILED(device->CreateShaderResourceView(r.edges_tex.get(), nullptr, r.edges_srv.put()))) return false;
         desc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
         if (FAILED(device->CreateTexture2D(&desc, nullptr, r.blend_tex.put()))) return false;
         if (FAILED(device->CreateUnorderedAccessView(r.blend_tex.get(), nullptr, r.blend_uav.put()))) return false;
         if (FAILED(device->CreateShaderResourceView(r.blend_tex.get(), nullptr, r.blend_srv.put()))) return false;
         r.width = width; r.height = height;
         return true;
      }

      bool CreateColorCopy(ID3D11Device* device, Resources& r, ID3D11Texture2D* color_tex, ID3D11ShaderResourceView* color_srv)
      {
         D3D11_TEXTURE2D_DESC desc;
         color_tex->GetDesc(&desc);
         D3D11_SHADER_RESOURCE_VIEW_DESC srv_desc;
         color_srv->GetDesc(&srv_desc);
         if (r.color_copy_tex && r.color_copy_desc.Width == desc.Width && r.color_copy_desc.Height == desc.Height && r.color_copy_desc.Format == desc.Format && r.color_copy_srv_format == srv_desc.Format) return true;
         r.color_copy_tex.reset(); r.color_copy_srv.reset();
         desc.MipLevels = 1; desc.ArraySize = 1; desc.SampleDesc.Count = 1; desc.SampleDesc.Quality = 0;
         desc.Usage = D3D11_USAGE_DEFAULT; desc.BindFlags = D3D11_BIND_SHADER_RESOURCE; desc.CPUAccessFlags = 0; desc.MiscFlags = 0;
         if (FAILED(device->CreateTexture2D(&desc, nullptr, r.color_copy_tex.put()))) return false;
         D3D11_SHADER_RESOURCE_VIEW_DESC copy_srv_desc = {};
         copy_srv_desc.Format = srv_desc.Format;
         copy_srv_desc.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2D;
         copy_srv_desc.Texture2D.MipLevels = 1;
         if (FAILED(device->CreateShaderResourceView(r.color_copy_tex.get(), &copy_srv_desc, r.color_copy_srv.put()))) return false;
         r.color_copy_desc = desc;
         r.color_copy_srv_format = srv_desc.Format;
         return true;
      }

      bool Run(ID3D11Device* device, ID3D11DeviceContext* ctx, DeviceData& device_data, Resources& r, ID3D11UnorderedAccessView* out_uav)
      {
         auto cs_edges = device_data.native_compute_shaders.find(CS_EDGE_DETECTION);
         auto cs_weights = device_data.native_compute_shaders.find(CS_BLENDING_WEIGHTS);
         auto cs_blend = device_data.native_compute_shaders.find(CS_NEIGHBORHOOD_BLENDING);
         if (cs_edges == device_data.native_compute_shaders.end() || !cs_edges->second.get() || cs_weights == device_data.native_compute_shaders.end() || !cs_weights->second.get() || cs_blend == device_data.native_compute_shaders.end() || !cs_blend->second.get()) return false;
         if (!r.luma_srv || !r.color_srv || !out_uav) return false;

         ComPtr<ID3D11Resource> out_res;
         out_uav->GetResource(out_res.put());
         ComPtr<ID3D11Texture2D> out_tex;
         if (!out_res || FAILED(out_res->QueryInterface(out_tex.put()))) return false;
         D3D11_TEXTURE2D_DESC out_desc;
         out_tex->GetDesc(&out_desc);
         D3D11_UNORDERED_ACCESS_VIEW_DESC out_uav_desc;
         out_uav->GetDesc(&out_uav_desc);
         const uint32_t mip = out_uav_desc.ViewDimension == D3D11_UAV_DIMENSION_TEXTURE2D ? out_uav_desc.Texture2D.MipSlice : 0;
         const uint32_t width = (std::max)(1u, out_desc.Width >> mip), height = (std::max)(1u, out_desc.Height >> mip);

         ComPtr<ID3D11Resource> color_res;
         r.color_srv->GetResource(color_res.put());
         ComPtr<ID3D11Texture2D> color_tex;
         if (!color_res || FAILED(color_res->QueryInterface(color_tex.put()))) return false;
         D3D11_TEXTURE2D_DESC color_desc;
         color_tex->GetDesc(&color_desc);
         if (color_desc.Width != out_desc.Width || color_desc.Height != out_desc.Height) return false;
         const bool in_place = color_res.get() == out_res.get();
         last_frame_in_place = in_place;
         last_width = width; last_height = height;

         if (!CreateStatic(device, r) || !CreateSized(device, r, width, height)) return false;
         ID3D11ShaderResourceView* color_in = r.color_srv.get();
         if (in_place)
         {
            if (!CreateColorCopy(device, r, color_tex.get(), r.color_srv.get())) return false;
            ctx->CopyResource(r.color_copy_tex.get(), color_tex.get());
            color_in = r.color_copy_srv.get();
         }

         Constants c = {};
         c.rt_metrics[0] = 1.f / float(width); c.rt_metrics[1] = 1.f / float(height); c.rt_metrics[2] = float(width); c.rt_metrics[3] = float(height);
         if (subsample_mode != 0)
         {
            const bool odd = ((r.frame_parity & 1u) != 0u) != (subsample_mode == 2);
            const float idx = odd ? 1.f : 2.f;
            c.subsample_indices[0] = idx; c.subsample_indices[1] = idx; c.subsample_indices[2] = idx; c.subsample_indices[3] = 0.f;
         }
         ctx->UpdateSubresource(r.constants.get(), 0, nullptr, &c, 0, 0);

         DrawStateStack<DrawStateStackType::Compute> state;
         state.Cache(ctx, device_data.uav_max_count);

         static constexpr std::array<ID3D11ShaderResourceView*, 8> null_srvs = {};
         static constexpr std::array<ID3D11UnorderedAccessView*, 8> null_uavs = {};
         ID3D11Buffer* cb = r.constants.get();
         const std::array samplers = { r.sampler_linear.get(), r.sampler_point.get() };
         const uint32_t gx = (width + 7) / 8, gy = (height + 7) / 8;

         ctx->CSSetUnorderedAccessViews(0, uint32_t(null_uavs.size()), null_uavs.data(), nullptr);
         ctx->CSSetShaderResources(0, uint32_t(null_srvs.size()), null_srvs.data());
         ctx->CSSetConstantBuffers(0, 1, &cb);
         ctx->CSSetSamplers(0, uint32_t(samplers.size()), samplers.data());

         {
            ID3D11ShaderResourceView* srvs[1] = { r.luma_srv.get() };
            ID3D11UnorderedAccessView* uavs[1] = { r.edges_uav.get() };
            ctx->CSSetShaderResources(0, 1, srvs);
            ctx->CSSetUnorderedAccessViews(0, 1, uavs, nullptr);
            ctx->CSSetShader(cs_edges->second.get(), nullptr, 0);
            ctx->Dispatch(gx, gy, 1);
         }
         {
            ctx->CSSetUnorderedAccessViews(0, 1, null_uavs.data(), nullptr);
            ID3D11ShaderResourceView* srvs[3] = { r.edges_srv.get(), r.area_srv.get(), r.search_srv.get() };
            ID3D11UnorderedAccessView* uavs[1] = { r.blend_uav.get() };
            ctx->CSSetShaderResources(0, 3, srvs);
            ctx->CSSetUnorderedAccessViews(0, 1, uavs, nullptr);
            ctx->CSSetShader(cs_weights->second.get(), nullptr, 0);
            ctx->Dispatch(gx, gy, 1);
         }
         {
            ctx->CSSetUnorderedAccessViews(0, 1, null_uavs.data(), nullptr);
            ID3D11ShaderResourceView* srvs[3] = { color_in, r.blend_srv.get(), nullptr };
            ID3D11UnorderedAccessView* uavs[1] = { out_uav };
            ctx->CSSetShaderResources(0, 3, srvs);
            ctx->CSSetUnorderedAccessViews(0, 1, uavs, nullptr);
            ctx->CSSetShader(cs_blend->second.get(), nullptr, 0);
            ctx->Dispatch(gx, gy, 1);
         }
         ctx->CSSetUnorderedAccessViews(0, 1, null_uavs.data(), nullptr);
         ctx->CSSetShaderResources(0, 3, null_srvs.data());

         state.Restore(ctx);
         replaced_frames++;
         return true;
      }
   }

   inline bool OnDispatch(ID3D11Device* device, ID3D11DeviceContext* ctx, DeviceData& device_data, Resources& r, uint32_t cs_hash)
   {
      if (!IsSMAA1xHash(cs_hash)) return false;
      const Role role = DetectRole(ctx);
      if (role == Role::None) return false;

      if (role == Role::EdgeDetection)
      {
         r.ResetFrame();
         r.frame_parity++;
         if (!enabled) return false;
         std::array<ID3D11ShaderResourceView*, 3> srvs = {};
         ctx->CSGetShaderResources(0, uint32_t(srvs.size()), srvs.data());
         if (srvs[0]) srvs[0]->Release();
         r.luma_srv.attach(srvs[1]);
         r.color_srv.attach(srvs[2]);
         if (!r.luma_srv || !r.color_srv)
         {
            r.ResetFrame();
            return false;
         }
         r.pass1_seen = true;
         skipped_dispatches++;
         return true;
      }

      if (!r.pass1_seen) return false;

      if (role == Role::QueueResolve)
      {
         skipped_dispatches++;
         return true;
      }

      if (!r.replaced)
      {
         std::array<ID3D11UnorderedAccessView*, 3> uavs = {};
         ctx->CSGetUnorderedAccessViews(0, uint32_t(uavs.size()), uavs.data());
         ComPtr<ID3D11UnorderedAccessView> out_uav;
         out_uav.attach(uavs[2]);
         if (uavs[0]) uavs[0]->Release();
         if (uavs[1]) uavs[1]->Release();
         r.replaced = Run(device, ctx, device_data, r, out_uav.get());
         if (!r.replaced)
         {
            static bool warned = false;
            if (!warned)
            {
               reshade::log::message(reshade::log::level::warning, "SMAAReference: could not run the reference SMAA passes, SMAA 1x is disabled for this frame");
               warned = true;
            }
         }
      }
      skipped_dispatches++;
      return true;
   }
}
