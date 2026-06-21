#define GAME_CODDX11 1

#define ENABLE_NGX 1
// #define ENABLE_FIDELITY_SK 1

// For our inserted RenderIntermediatePass
#define ENABLE_POST_DRAW_DISPATCH_CALLBACK 1

#include "..\..\Core\core.hpp"
#include ".\draw1.hpp"
// #include ".\Includes\shader_define_info.h"
// #include ".\Includes\game_identity.h"
// #include ".\Includes\cods.h"
// #include ".\Includes\sectioned_imgui.h"

namespace Globals
{
   // User
   static bool imgui_is_advanced = false;
   static bool pipeline_is_ui = true;
   static bool pipeline_is_skipondrawordispatch = false;

   // Helpers
   static float InverseLerp(float a, float b, float v)
   {
      if (a == b) return 0.f;
      return (v - a) / (b - a);
   }

   float3 HSV_To_RGB(float3 HSV)
   {
      float h1 = HSV.x * 6.f;
      float c = HSV.z * HSV.y;
      float x = c * ( 1.f - abs(fmod(h1, 2.f) - 1.f));
      float3 rgb = float3(0,0,0);
      if( h1 <= 1.f )
         rgb = float3( c, x, 0.f );
      else if( h1 <= 2.f )
         rgb = float3( x, c, 0.f );
      else if( h1 <= 3.f )
         rgb = float3( 0.f, c, x );
      else if( h1 <= 4.f )
         rgb = float3( 0.f, x, c );
      else if( h1 <= 5.f )
         rgb = float3( x, 0.f, c );
      else if( h1 <= 6.f )
         rgb = float3( c, 0.f, x );
      float m = HSV.z - c;
      return float3(rgb.x + m, rgb.y + m, rgb.z + m);
   }

   // Buffer
   struct Buffer
   {
      D3D11_TEXTURE2D_DESC desc;
      com_ptr<ID3D11Texture2D> tex;
      com_ptr<ID3D11Resource> res;
      com_ptr<ID3D11ShaderResourceView> srv;
      com_ptr<ID3D11RenderTargetView> rtv;
      com_ptr<ID3D11UnorderedAccessView> uav;

      uint2 GetDimensions() const
      {
         return { desc.Width, desc.Height };
      }
      
      void Reset()
      {
         desc = {};
         res = nullptr;
         tex = nullptr;
         srv = nullptr;
         rtv = nullptr;
         uav = nullptr;
      }

      void CreateWithCurrentDesc(ID3D11Device* device)
      {
         auto hr0 = device->CreateTexture2D(&desc, nullptr, &tex);
         if (DEVELOPMENT) ASSERT_ONCE(SUCCEEDED(hr0));

         auto hr1 = tex->QueryInterface(&res);
         if (DEVELOPMENT) ASSERT_ONCE(SUCCEEDED(hr1));

         auto hr2 = device->CreateRenderTargetView(tex.get(), nullptr, &rtv);
         if (DEVELOPMENT) ASSERT_ONCE(SUCCEEDED(hr2));
      
         auto hr3 = device->CreateShaderResourceView(tex.get(), nullptr, &srv);
         if (DEVELOPMENT) ASSERT_ONCE(SUCCEEDED(hr3));
      }

      static D3D11_TEXTURE2D_DESC GetDefaultDesc(uint2 output_resolution, DXGI_FORMAT format = DXGI_FORMAT_R16G16B16A16_FLOAT) //TODO: from BO3, is this same?
      {
         D3D11_TEXTURE2D_DESC desc = {};
         desc.Width = output_resolution.x;
         desc.Height = output_resolution.y;
         desc.MipLevels = 1;
         desc.ArraySize = 1;
         desc.BindFlags = D3D11_BIND_SHADER_RESOURCE | D3D11_BIND_RENDER_TARGET | D3D11_BIND_UNORDERED_ACCESS;
         desc.Usage = D3D11_USAGE_DEFAULT;
         desc.Format = format;
         desc.SampleDesc = {1, 0};
         desc.CPUAccessFlags = 0;
         desc.MiscFlags = 0;
         return desc;
      }

      void SetDefaultDesc(uint2 output_resolution, DXGI_FORMAT format = DXGI_FORMAT_R16G16B16A16_FLOAT)
      {
         desc = GetDefaultDesc(output_resolution, format);
      }
   };

   
   // Mem
   const uintptr_t base = std::bit_cast<uintptr_t>(GetModuleHandleA(nullptr));
}

namespace NativeShaders
{
   constexpr std::string_view Luma_h1_BlitBlurSkip_PS = "Luma_h1_BlitBlurSkip_PS";
   constexpr std::string_view Luma_h1_RenderIntermediatePass_PS = "Luma_h1_RenderIntermediatePass_PS";
   constexpr std::string_view Luma_h1_SMAAT2XSkip_PS = "Luma_h1_SMAAT2XSkip_PS";
   constexpr std::string_view Luma_h1_SRMotionVectorIn_PS = "Luma_h1_SRMotionVectorIn_PS";
   constexpr std::string_view Luma_h1_SRColorIn_PS = "Luma_h1_SRColorIn_PS";
   constexpr std::string_view Luma_h1_SRColorOut_PS = "Luma_h1_SRColorOut_PS";
   
   void OnInit()
   {
      native_shaders_definitions.emplace(CompileTimeStringHash(Luma_h1_BlitBlurSkip_PS), ShaderDefinition{Luma_h1_BlitBlurSkip_PS.data(), reshade::api::pipeline_subobject_type::pixel_shader});
      native_shaders_definitions.emplace(CompileTimeStringHash(Luma_h1_RenderIntermediatePass_PS), ShaderDefinition{Luma_h1_RenderIntermediatePass_PS.data(), reshade::api::pipeline_subobject_type::pixel_shader});
      native_shaders_definitions.emplace(CompileTimeStringHash(Luma_h1_SMAAT2XSkip_PS), ShaderDefinition{Luma_h1_SMAAT2XSkip_PS.data(), reshade::api::pipeline_subobject_type::pixel_shader});
      native_shaders_definitions.emplace(CompileTimeStringHash(Luma_h1_SRMotionVectorIn_PS), ShaderDefinition{Luma_h1_SRMotionVectorIn_PS.data(), reshade::api::pipeline_subobject_type::pixel_shader});
      native_shaders_definitions.emplace(CompileTimeStringHash(Luma_h1_SRColorIn_PS), ShaderDefinition{Luma_h1_SRColorIn_PS.data(), reshade::api::pipeline_subobject_type::pixel_shader});
      native_shaders_definitions.emplace(CompileTimeStringHash(Luma_h1_SRColorOut_PS), ShaderDefinition{Luma_h1_SRColorOut_PS.data(), reshade::api::pipeline_subobject_type::pixel_shader});
   }
}

namespace ShaderDefineInfo
{
   constexpr uint32_t GAMMA_CORRECTION_RANGE_TYPE = char_ptr_crc32("GAMMA_CORRECTION_RANGE_TYPE");
   constexpr uint32_t SWAPCHAIN_CLAMP_PEAK        = char_ptr_crc32("SWAPCHAIN_CLAMP_PEAK");
   constexpr uint32_t SWAPCHAIN_TEST_USER_PEAK    = char_ptr_crc32("SWAPCHAIN_TEST_USER_PEAK");
   constexpr uint32_t SWAPCHAIN_TEST_IS_BLACK     = char_ptr_crc32("SWAPCHAIN_TEST_IS_BLACK");
   static const std::vector<ShaderDefineData> game_shader_defines_data = {
      {"GAMMA_CORRECTION_RANGE_TYPE", '0', true, true, "0 - Full range.\n1 - 0-1 only.", 1},
      {"SWAPCHAIN_CLAMP_PEAK", '0', true, false, "Final color clamp before present.\n0 - Unclamped (up to display).\n1 - Per channel clamp (blows out).", 1},
      {"SWAPCHAIN_TEST_USER_PEAK", '0', true, false, "Show a simple white rectangle peak test.", 1},
      {"SWAPCHAIN_TEST_IS_BLACK", '0', true, false, "If not 0, force to brighter", 1},
   };
   
   static char InvertCharBool(char b)
   {
      return b == '0' ? '1' : '0'; 
   }
   
   //This feels dumb O(n) everytime, but it is the most consistent.
   static int Get(uint32_t p)
   {
      auto* d = &GetShaderDefineData(p);
      return d->editable_data.value[0] - '0';
   }

   static bool GetBool(uint32_t p)
   {
      return Get(p) > 0;
   }

   static void Set(uint32_t p, char c)
   {
      auto* d = &GetShaderDefineData(p);
      if (d->editable_data.value[0] == c) return;
      d->SetValue(c);
      defines_need_recompilation = true;
   }
   
   static void Set(uint32_t p, int i)
   {
      auto* d = &GetShaderDefineData(p);
      char c = static_cast<char>(i + '0');
      Set(p, c);
   }

   static void Set(uint32_t p, bool b)
   {
      int i = b ? 1 : 0;
      Set(p, i);
   }

   static void ToggleBool(uint32_t p)
   {
      auto* d = &GetShaderDefineData(p);
      d->SetValue(InvertCharBool(d->editable_data.value[0]));
      defines_need_recompilation = true;
   }

   static void UIResetButton(uint32_t p)
   {
      auto* d = &GetShaderDefineData(p);
      if (d->editable_data.value[0] != d->default_data.value[0]) {
         int id = static_cast<int>(reinterpret_cast<uintptr_t>(d));
         ImGui::PushID(id);
         ImGui::SameLine();
         if (ImGui::SmallButton(ICON_FK_UNDO))
         {
            d->Reset();
            defines_need_recompilation = true;
         }
         ImGui::PopID();
      }
   }

   static bool UIToggleCheckmark(uint32_t d, const char* label, const char* tooltip)
   {
      bool def = GetBool(d);
      
      ImGui::PushID(std::string(label).append("_").append(std::to_string(d)).c_str());
      bool c = ImGui::Checkbox(label, &def);
      ImGui::PopID();

      if (ImGui::IsItemHovered(ImGuiHoveredFlags_AllowWhenDisabled)) ImGui::SetTooltip(tooltip);
      
      if (c) ToggleBool(d);
      
      UIResetButton(d);
      return def;
   }
      
   static int UIDropDown(uint32_t d, const char* label, const char* const items[], const char* tooltip)
   {
      int def = Get(d);
      bool c = ImGui::Combo(label, &def, items, IM_ARRAYSIZE(items));
      if (c) Set(d, def);
      if (ImGui::IsItemHovered(ImGuiHoveredFlags_AllowWhenDisabled)) ImGui::SetTooltip(tooltip);
      UIResetButton(d);
      return def;
   }

   static int UIDropDown(uint32_t d, const char* label, std::initializer_list<const char*> items_list, const char* tooltip)
   {
      std::vector<const char*> items(items_list);
      int def = Get(d);
      ImGui::PushID(std::string(label).append("_").append(std::to_string(d)).c_str());
      bool c = ImGui::Combo(label, &def, items.data(), static_cast<int>(items.size()));
      ImGui::PopID();
      if (c) Set(d, def);
      if (tooltip && ImGui::IsItemHovered(ImGuiHoveredFlags_AllowWhenDisabled)) ImGui::SetTooltip(tooltip);
      UIResetButton(d);
      return def;
   }
}

namespace Website
{
   void OpenWebsite(const char* url) {
#if defined(_WIN32) || defined(_WIN64)
      std::string command = "start " + std::string(url);
      std::system(command.c_str());
#elif defined(__linux__)
      std::string command = "xdg-open " + std::string(url);
      std::system(command.c_str());
#elif defined(__APPLE__)
      std::string command = "open " + std::string(url);
      std::system(command.c_str());
#endif
   }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

namespace GameIdentity
{
   enum GameType
   {
      Unknown = 0,
      H1 = 1,
      H2 = 2,
   };
   constexpr std::string_view GameTypeToString(GameType game)
   {
      switch (game)
      {
      case H1: return "H1";
      case H2: return "H2";
      default: return "Unknown";
      }
   }
   static GameType game = Unknown;

   static const char* GameTypeGetLumaFlagFile(GameType game)
   {
      auto flag_file = "Luma_";
      auto txt = ".txt";

      switch (game)
      {
         case H1: return std::string(flag_file + std::string(GameTypeToString(H1)) + txt).c_str();
         case H2: return std::string(flag_file + std::string(GameTypeToString(H2)) + txt).c_str();
         default: return std::string(flag_file + std::string(GameTypeToString(Unknown)) + txt).c_str();
      }
   }

   static GameType OnDllMain()
   {
      // reset
      game = Unknown;
   
      // GetModuleFileNameA
      std::string filename_lower;
      {
         char path[MAX_PATH];
         if (GetModuleFileNameA(nullptr, path, MAX_PATH) == 0) goto AfterGetModuleFileNameA;

         // get lowercase filename from path
         {
            const char* f = strrchr(path, '\\');
            if (f) f++;
            else f = path;

            filename_lower = f;
            std::ranges::transform(filename_lower, filename_lower.begin(), ::tolower);
         }
         
         // h1
         if (game == Unknown && (strstr(filename_lower.c_str(), "h1") != nullptr || strstr(filename_lower.c_str(), "pccallofdutymodernwarfareremastered") != nullptr))
            game = H1;
   
         // h2
         if (game == Unknown && (strstr(filename_lower.c_str(), "h2") != nullptr || strstr(filename_lower.c_str(), "mw2") != nullptr))
            game = H2;
      }
      AfterGetModuleFileNameA:
   
      //flag file
      if (game == Unknown)
      {
         // h1
         if (game == Unknown && std::filesystem::exists(GameTypeGetLumaFlagFile(H1)))
            game = H1;

         // h2
         if (game == Unknown && std::filesystem::exists(GameTypeGetLumaFlagFile(H2)))
            game = H2;
      }
   
      // give up, ask user to create a flag file
      if (game == Unknown)
      {
         // Luma_Unknown
         if (!std::filesystem::exists(GameTypeGetLumaFlagFile(Unknown)))
         {
            std::ofstream flag_file(GameTypeGetLumaFlagFile(Unknown));
            flag_file << "Please rename this file to..."
                         "\n - \"Luma_H1\" for Call of Duty: Modern Warfare 1 Remastered"
                         "\n - \"Luma_H2\" for Call of Duty: Modern Warfare 2 Remastered";
            flag_file.close();
         }
         ASSERT_MSG(game != Unknown, "FATAL ERROR! Failed to identify the game.\nPlease find the text file \"Luma_Unknown\" and read the instructions inside.");

         // force exit code 1
         std::exit(1);
      }
   
      return game;
   }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

namespace SR
{
   static bool IsOn()
   {
      return sr_user_type != SR::UserType::None;
   }

   SettingsData settings_data = {};
   SuperResolutionImpl::DrawData draw_data = {};
   static bool ignore_upgraded_samplers_user = false;
   void SetMvsScale(float2 scale)   
   {
      settings_data.mvs_x_scale = scale.x;
      settings_data.mvs_y_scale = scale.y;
   }

   namespace Jitter
   {
      constexpr float4 expected_jitter = float4(-0.25f, 0.25f, 0.25f, -0.25f);
      
      static float4* addr; // DON'T SET DIRECTLY, use SetAddressByOffsetIfVerified
      bool IsReady() { return addr != nullptr; }

      static uint phases_curr;
      static uint phases_user;
      static float2 jitter_curr;
      static float2 jitter_prev;
      static bool is_flipsync = false;
      static bool is_desynctest = false;
      static bool is_neg_x = false;
      static bool is_neg_y = true;
      static bool is_prev = true;
      static bool is_setboth = false;
      static bool is_mvjittered = false;
      static bool is_t2xjitter = false;
      
      static bool VerifyJitterAtAddress(float4* a)
      {
         if (a == nullptr) return false;
         if (a->x != expected_jitter.x) return false;
         if (a->y != expected_jitter.y) return false;
         if (a->z != expected_jitter.z) return false;
         if (a->w != expected_jitter.w) return false;
         
         return true;
      }

      static bool SetAddressByOffsetIfVerified(uint offset, reshade::api::effect_runtime* runtime)
      {
         // failed?
         if (offset == 0) return false;
         if (!VerifyJitterAtAddress(std::bit_cast<float4*>(Globals::base + offset))) return false;

         // success!
         addr = std::bit_cast<float4*>(Globals::base + offset);

         // disarm VirtualProtect if needed
         DWORD old_protect;
         VirtualProtect(addr, sizeof(float4), PAGE_EXECUTE_READWRITE, &old_protect);

         // save
         message(reshade::log::level::info,  std::string("Jitter offset found and set: " + std::format("{:#x}", offset)).c_str());
         reshade::set_config_value(runtime, NAME, "JitterOffset", offset);
         
         return true;
      }

      static bool SetAddressFromScanIfVerified(reshade::api::effect_runtime* runtime)
      {
         const uintptr_t start = Globals::base;
         const uintptr_t end = Globals::base + 0x7FFFFFFF;
         for (uintptr_t addr = start; addr < end; addr += 16)
            if (SetAddressByOffsetIfVerified(static_cast<uint>(addr - Globals::base), runtime))
               return true;
         return false;
      }

      static bool TryDisarm(reshade::api::effect_runtime* runtime)
      {
         if (!IsReady()) return false;
         *addr = expected_jitter;
         reshade::set_config_value(runtime, NAME, "JitterOffset", 0);
         addr = nullptr;
         return true;
      }

      static float2 GetJitterEffective()
      {
         if (!IsReady()) return float2(0, 0);
         float2 j = is_prev ? jitter_prev : jitter_curr;
         if (is_neg_x) j.x = -j.x;
         if (is_neg_y) j.y = -j.y;
         return j;
      }
      
      static void OnPresent(ID3D11Device* native_device, DeviceData& device_data)
      {
         if (!IsOn())
         {
            if (IsReady()) *addr = expected_jitter;
            return;
         }

         if (DEVELOPMENT) ASSERT(sr_implementations[device_data.sr_type] != nullptr); //impossible
         if (!IsReady()) return;

         // efdfective frame counter
         uint frame_effective = cb_luma_global_settings.FrameIndex + is_flipsync;     //global with offset to fix desync //TODO: detect and fix desync

         // case: Halton
         if (!is_t2xjitter)
         {
            // phases
            if (phases_user != 0)
            {
               phases_curr = phases_user;
            }
            else
            {
               phases_curr = SR::GetDefaultJitterPhases();
               auto* sr_instance_data = device_data.GetSRInstanceData();
               phases_curr = sr_implementations[device_data.sr_type]->GetJitterPhases(sr_instance_data);
            }

            // effective frame index

            // jitter get
            const uint temporal_frame = frame_effective % phases_curr;
            jitter_prev = jitter_curr;
            jitter_curr = float2(SR::HaltonSequence(temporal_frame, 2), SR::HaltonSequence(temporal_frame, 3)); //new
            if (is_desynctest) jitter_curr = float2(jitter_curr.x * 4, jitter_curr.y * 4); //desync test

            // jitter set
            if (!is_setboth)
            {
               if (frame_effective % 2 != 0)
               {
                  addr->x = jitter_curr.x;
                  addr->y = jitter_curr.y;
               }
               else
               {
                  addr->z = jitter_curr.x;
                  addr->w = jitter_curr.y;
               }
            }
            else
            {
               *addr = float4(jitter_curr.x, jitter_curr.y, jitter_curr.x, jitter_curr.y);
            }
         }
         // case: T2X
         else
         {
            *addr = expected_jitter;
            jitter_prev = jitter_curr;
            jitter_curr = frame_effective % 2 != 0 ? float2(expected_jitter.x, expected_jitter.y) : float2(expected_jitter.z, expected_jitter.w);
         }
      }
      
      static void OnLoad(reshade::api::effect_runtime* runtime)
      {
         uint o = 0;
         auto s = reshade::get_config_value(runtime, NAME, "JitterOffset", o);
         
         if (s) SetAddressByOffsetIfVerified(o, runtime);
         else SetAddressFromScanIfVerified(runtime);
      }
   }
   
   namespace Buffers
   {
      Globals::Buffer color_out;
      Globals::Buffer color_in;
      Globals::Buffer color_in_linear;
      Globals::Buffer depth;
      Globals::Buffer motionvectors;
      Globals::Buffer motionvectors_linear;

      // in dim
      uint2 GetRenderResolution()
      {
         return color_in.GetDimensions();
      }
      
      // in / out
      float GetRenderRatio()
      {
         return static_cast<float>(color_in.desc.Height) / static_cast<float>(color_out.desc.Height);
      }

      // in = out
      bool IsNativeResolution()
      {
         if (/*color_in.desc.Width != color_out.desc.Width ||*/ color_in.desc.Height != color_out.desc.Height) return false;
         return true;
      }

      // invalidate 
      void HardReset()
      {
         color_out.Reset();
         color_in.Reset();
         color_in_linear.Reset();
         depth.Reset();
         motionvectors.Reset();
         motionvectors_linear.Reset();
      }

      // output color is read to go
      bool IsReady()
      {
         return color_out.res != nullptr;
      }

      // create all sub-components
      void Create(ID3D11Device* device, uint2 render_resolution, uint2 output_resolution)
      {
         // color_out
         color_out.Reset();
         color_out.SetDefaultDesc(output_resolution);
         color_out.CreateWithCurrentDesc(device);

         // color_in_linear
         color_in_linear.Reset();
         color_in_linear.SetDefaultDesc(render_resolution);
         color_in_linear.CreateWithCurrentDesc(device);

         // motionvectors_linear
         motionvectors_linear.Reset();
         motionvectors_linear.SetDefaultDesc(render_resolution, DXGI_FORMAT_R16G16_FLOAT);
         motionvectors_linear.CreateWithCurrentDesc(device);
      }
   }

   static bool Draw(DeviceData& device_data, ID3D11DeviceContext* context, InstanceData* instance_data, uint2 render_resolution, uint2 output_resolution,
      ID3D11Resource* depth_buffer, ID3D11Resource* motion_vectors, ID3D11Resource* source_color, ID3D11Resource* output_color)
   {      
      // SettingsData
      {
         settings_data.output_width  = output_resolution.x;
         settings_data.output_height = output_resolution.y;
         settings_data.render_width  = render_resolution.x;
         settings_data.render_height = render_resolution.y;
         settings_data.inverted_depth = true;
         settings_data.hdr = cb_luma_global_settings.DisplayMode != DisplayModeType::SDR;
         settings_data.mvs_x_scale = 1;
         settings_data.mvs_y_scale = 1;
         settings_data.mvs_jittered = Jitter::is_mvjittered;
         settings_data.auto_exposure = true;
         settings_data.render_preset = dlss_render_preset;
         sr_implementations[device_data.sr_type]->UpdateSettings(instance_data, context, settings_data);
      }

      // DrawData
      {
         float2 jitter = Jitter::GetJitterEffective();
         draw_data.jitter_x = jitter.x;
         draw_data.jitter_y = jitter.y;
         
         // game_device_data.sr_draw_data.user_sharpness = Globals::SRSharpness;
         // draw_data.pre_exposure = Globals::SRPreExposure;
         draw_data.render_width  = render_resolution.x;
         draw_data.render_height = render_resolution.y;
         draw_data.near_plane = 0;
         draw_data.far_plane  = 1;
         draw_data.source_color = source_color;
         ASSERT_MSG(draw_data.source_color != nullptr, "SR FATAL ERROR: source_color is null! This should never happen, please report!");
         draw_data.output_color = output_color;
         ASSERT_MSG(draw_data.output_color != nullptr, "SR FATAL ERROR: output_color is null! This should never happen, please report!");
         draw_data.motion_vectors = motion_vectors;
         ASSERT_MSG(draw_data.motion_vectors != nullptr, "SR FATAL ERROR: motion_vectors is null! This should never happen, please report!");
         draw_data.depth_buffer = depth_buffer;
         ASSERT_MSG(draw_data.depth_buffer != nullptr, "SR FATAL ERROR: depth_buffer is null! This should never happen, please report!");
         //game_device_data.sr_draw_data.exposure = nullptr;
      }

      // DRAW!
      return sr_implementations[device_data.sr_type]->Draw(instance_data, context, draw_data);
   }

   void OnPreset(ID3D11Device* native_device, DeviceData& device_data)
   {
      //mipmap bias
      if (!custom_texture_mip_lod_bias_offset && IsOn()) device_data.texture_mip_lod_bias_offset = GetMipLODBias(SR::Buffers::color_in.desc.Height, static_cast<int>(cb_luma_global_settings.SwapchainSize.y));
      else device_data.texture_mip_lod_bias_offset = 0;

      //sampler upgrade
      if (!IsOn()) ignore_upgraded_samplers = true;
      else ignore_upgraded_samplers = ignore_upgraded_samplers_user;

      //render res cb
      // cb_luma_global_settings.GameSettings.RenderResolutionScale = SR::IsOn() ? Buffers::GetRenderRatio() : -1; //%
   }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

namespace SectionedImGui 
{   
   struct Base
   {
      virtual ~Base() = default;
      virtual void OnDllMain() = 0;
      virtual void OnDrawContentsForced(DeviceData& device_data, reshade::api::effect_runtime* runtime) {
         // Gamma Correction
         ShaderDefineInfo::Set(GAMMA_CORRECTION_TYPE_HASH, custom_sdr_gamma > 0);
      }
   };
   inline std::unique_ptr<Base> sectioned_imgui;

   namespace Templates
   {
      static float GetPulseMultiplier(float speed = 0.1f, float amount = 0.25f)
      {
         return (1.f-amount/2) + amount/2 * sinf(cb_luma_global_settings.FrameIndex * speed);
      }
      
      static void README(DeviceData& device_data, reshade::api::effect_runtime* runtime)
      {
         // pulsing text
         auto pulse = GetPulseMultiplier();
         auto green = float3(0.75f, 1.f, 0.75f);
         auto color = ImVec4(green.x * pulse, green.y * pulse, green.z * pulse, 1.f);
         ImGui::PushStyleColor(ImGuiCol_Text, color);
         ImGui::TextWrapped("[Thanks For Downloading!]");
         ImGui::PopStyleColor();
         
         // Info
         ImGui::Bullet(); ImGui::SameLine(); ImGui::TextWrapped("This acts as a wizard to fully configure.");
         ImGui::Bullet(); ImGui::SameLine(); ImGui::TextWrapped("Please at least view all sections!");

         ImGui::Separator(); ////////////////////

         //GameTypeToString
         ImGui::Bullet(); ImGui::SameLine(); ImGui::TextWrapped(std::string("Detected Game: " + std::string(GameIdentity::GameTypeToString(GameIdentity::game))).c_str());
      }
      
      static void GammaCorrection(DeviceData& device_data, reshade::api::effect_runtime* runtime)
      {
         // Info
         ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(1.f, 1.f, 0.75f, 1.f));
         ImGui::TextWrapped("[SDR/HDR Gamma Mismatch]");
         ImGui::PopStyleColor();
         ImGui::Bullet(); ImGui::SameLine(); ImGui::TextWrapped("Windows' gamma in HDR is weaker than in SDR, causing washed out shadows.");
         /*ImGui::Bullet(); ImGui::SameLine();*/ if (ImGui::Button("Further Explanation & Test (Google Slides)"))
            Website::OpenWebsite("https://docs.google.com/presentation/d/e/2PACX-1vSXeLHlbm6repcS7fels1-SXYGRmzziRrnuJ8nDO8J5rsWV3dT1-nVyCKp0Tj_stwx-9qlCI-N6rYIT/pub?start=false&loop=false&slide=id.g3e007eafba8_0_0");

         ImGui::Separator();
         
         // Dropdown for custom_sdr_gamma
         const char* const items[] = { "Off (sRGB)", "Match SDR (2.2)", "Stronger (2.4)" };
         int custom_sdr_gamma_index = 0;
         if (custom_sdr_gamma > 0) { //detect
            if (abs(custom_sdr_gamma - 2.2f) < 0.001f) custom_sdr_gamma_index = 1;
            else if (custom_sdr_gamma == 2.4f) custom_sdr_gamma_index = 2;
         }
         ImGui::PushID("GammaCorrection custom_sdr_gamma");
         if (ImGui::Combo("Correction", &custom_sdr_gamma_index, items, IM_ARRAYSIZE(items))) //user set & save
         {
            switch (custom_sdr_gamma_index)
            {
               default: custom_sdr_gamma = 0.f; break;
               case 1: custom_sdr_gamma = 2.2f; break;
               case 2: custom_sdr_gamma = 2.4f; break;
            }
            ShaderDefineInfo::Set(GAMMA_CORRECTION_TYPE_HASH, custom_sdr_gamma > 0);
            defines_need_recompilation = true;
            reshade::set_config_value(runtime, NAME, "custom_sdr_gamma", custom_sdr_gamma);
         }
         ImGui::PopID();
      }
      
      static void InGameSettingsWarning(DeviceData& device_data, reshade::api::effect_runtime* runtime)
      {
         //color red
         ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(1.f, 0.75f, 0.75f, 1.f));
         ImGui::TextWrapped("[IMPORTANT / WARNING]");
         ImGui::PopStyleColor();
         ImGui::Bullet(); ImGui::SameLine(); ImGui::TextWrapped("After loading in, changing graphics settings is crash proned. (Only if not Exclusive Fullscreen?)");
         ImGui::Bullet(); ImGui::SameLine(); ImGui::TextWrapped("If you consistently crash trying to load in a specific level, delete the game's shader cache.");

         ImGui::Separator();

         ImGui::Checkbox("Safe Mode (Read Tooltip)", &Globals::pipeline_is_skipondrawordispatch);
         if (ImGui::IsItemHovered(ImGuiHoveredFlags_AllowWhenDisabled)) ImGui::SetTooltip("Use this as a last resort to change settings, though it probably won't work.\n(This will skip this mod's custom pipeline scanning, breaking HDR handling.)");
      }
      
      static void InGameSettingsBrightness(DeviceData& device_data, reshade::api::effect_runtime* runtime)
      {
         ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(1.f, 1.f, 0.75f, 1.f));
         ImGui::TextWrapped("[\"BRIGHTNESS\"]");
         ImGui::PopStyleColor();
         ImGui::Bullet(); ImGui::SameLine(); ImGui::TextWrapped("The algorithm for the in-game BRIGHTNESS setting is SDR-centric, ruining HDR calculations.");
         if (GameIdentity::game == GameIdentity::H1) {ImGui::Bullet(); ImGui::SameLine(); ImGui::TextWrapped("Please calibrate it (\"NOT VISIBLE\" should disappear).");}
         if (GameIdentity::game == GameIdentity::H2) {ImGui::Bullet(); ImGui::SameLine(); ImGui::TextWrapped("Please reset it within its test screen.");}
         ImGui::Separator();
         ShaderDefineInfo::UIToggleCheckmark(ShaderDefineInfo::SWAPCHAIN_TEST_IS_BLACK, "Black Test", "For verifying \"NOT VISIBLE\".\nAny pixels not 0 will be forced to a bright value.");
      }
      
      static void HDRBrightness(DeviceData& device_data, reshade::api::effect_runtime* runtime)
      {
         ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(0.75f, 0.75f, 1.f, 1.f));
         ImGui::TextWrapped("[HDR Luminance Tonemapping]");
         ImGui::PopStyleColor();
         ImGui::Bullet(); ImGui::SameLine(); ImGui::TextWrapped("Use default Luma sliders above!");
         if (GameIdentity::game == GameIdentity::H1) {ImGui::Bullet(); ImGui::SameLine(); ImGui::TextWrapped("(MW1R) This game is severely underexposed, and I have boosted it to roughly match MW2R.");}

         float stops = cb_luma_global_settings.ScenePeakWhite / cb_luma_global_settings.ScenePaperWhite;
         stops = std::log2(stops);
         if (stops > 0) ImGui::BulletText("HDR Stops According to Peak & Paper: +%.2f", stops);

         ImGui::Separator();

         ImGui::PushID("HDRBrightness: Exposure Pre");
         if (ImGui::SliderFloat("Pre Exposure", &cb_luma_global_settings.GameSettings.ExposurePre, 0.f, 3.f, "%.3f"))
            reshade::set_config_value(runtime, NAME, "ExposurePre", cb_luma_global_settings.GameSettings.ExposurePre);
         ImGui::PopID();
         if (ImGui::IsItemHovered(ImGuiHoveredFlags_AllowWhenDisabled))
            ImGui::SetTooltip("Exposure multiplier of raw linear color,\nright after scene rendering is done,\nand before per-channel tonemap that will then cause blowout.");
         DrawResetButton(cb_luma_global_settings.GameSettings.ExposurePre, default_luma_global_game_settings.ExposurePre, "ExposurePre", runtime);

         ImGui::PushID("HDRBrightness: Exposure Post");
         if (ImGui::SliderFloat("Post Exposure", &cb_luma_global_settings.GameSettings.ExposurePost, 0.f, 3.f, "%.3f"))
            reshade::set_config_value(runtime, NAME, "ExposurePost", cb_luma_global_settings.GameSettings.ExposurePost);
         ImGui::PopID();
         if (ImGui::IsItemHovered(ImGuiHoveredFlags_AllowWhenDisabled))
            ImGui::SetTooltip("Exposure on color right before luminance HDR tonemap to Display Peak, which doesn't cause blowout.");
         DrawResetButton(cb_luma_global_settings.GameSettings.ExposurePost, default_luma_global_game_settings.ExposurePost, "ExposurePost", runtime);
         
         if (ImGui::SliderFloat("FMV Paper White", &cb_luma_global_settings.GameSettings.FMVPaperWhite, 1.f, 500.f, "%.0f"))
            reshade::set_config_value(runtime, NAME, "FMVPaperWhite", cb_luma_global_settings.GameSettings.FMVPaperWhite);
         ImGui::PopID();
         if (ImGui::IsItemHovered(ImGuiHoveredFlags_AllowWhenDisabled))
            ImGui::SetTooltip("Separate brightness for video files (e.g. loading).");
         DrawResetButton(cb_luma_global_settings.GameSettings.FMVPaperWhite, default_luma_global_game_settings.FMVPaperWhite, "FMVPaperWhite", runtime);
         
         ShaderDefineInfo::UIToggleCheckmark(ShaderDefineInfo::SWAPCHAIN_TEST_USER_PEAK, "Test Pattern (Read Tooltip)", "Show a simple test pattern (2 Rectangles: 10000 nits outer VS user settings inner) to check if the display peak brightness is correctly set.\n\n- If display is set to HGiG, which hard clips, the technically best value is the lowest where the inner rectangle disappears.\n- If display is set to Static Tonemap, it will try to compress the full 10000 nits down, so you have to search up your model, or eye it by finding when the roll off starts.\n\nAlso consider other factors like chrominance loss at higher nits, Automatic Brightness Limiter (ABL), and personal preference.");
      }
      
      static bool is_show_pcc_ucs = false; 
      static void PerChannelCorrection(DeviceData& device_data, reshade::api::effect_runtime* runtime)
      {
         ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(0.75f, 0.75f, 1.f, 1.f));
         ImGui::TextWrapped("[Per-Channel Correction via SDR Tonemap Extension]");
         ImGui::PopStyleColor();
         ImGui::Bullet(); ImGui::SameLine(); ImGui::TextWrapped("A per-channel tonemap extension all the way up to Display Peak can lead to unintended highlights like orange/red fire.");
         ImGui::Bullet(); ImGui::SameLine(); ImGui::TextWrapped("Instead, we can pick a different peak, balanced between recovery and the original asset intent & limitation.");

         ImGui::Separator();
         
         ImGui::PushID("PCC: Peak");
         if (ImGui::SliderFloat("Peak", &cb_luma_global_settings.GameSettings.PCCPeak, 1.f, 10.f, "%.4f", ImGuiSliderFlags_Logarithmic))
            reshade::set_config_value(runtime, NAME, "PCCPeak", cb_luma_global_settings.GameSettings.PCCPeak);
         ImGui::PopID();
         if (ImGui::IsItemHovered(ImGuiHoveredFlags_AllowWhenDisabled)) ImGui::SetTooltip("The peak for the extended per-channel tonemapper from which we obtain new extended chrominance & hue.");
         DrawResetButton(cb_luma_global_settings.GameSettings.PCCPeak, default_luma_global_game_settings.PCCPeak, "PCCPeak", runtime);

         if (ImGui::Button(std::format("Match Display Peak ÷ Paper ({:.2f})", cb_luma_global_settings.ScenePeakWhite / cb_luma_global_settings.ScenePaperWhite).c_str()))
         {
            cb_luma_global_settings.GameSettings.PCCPeak = cb_luma_global_settings.ScenePeakWhite / cb_luma_global_settings.ScenePaperWhite;
            reshade::set_config_value(runtime, NAME, "PCCPeak", cb_luma_global_settings.GameSettings.PCCPeak);
         }
         if (ImGui::IsItemHovered(ImGuiHoveredFlags_AllowWhenDisabled)) ImGui::SetTooltip("Match Chrominance Extension to Luminance Extension.\nTechnically correct, but usually too high, which leads to unintended highlights like orange/red fire.");
         
         
         if (is_show_pcc_ucs)
         {
            ImGui::PushID("PCC: Hue");
            if (ImGui::SliderFloat("Hue Strength", &cb_luma_global_settings.GameSettings.PCCHue, 0.f, 1.f, "%.3f"))
               reshade::set_config_value(runtime, NAME, "PCCHue", cb_luma_global_settings.GameSettings.PCCHue);
            ImGui::PopID();
            if (ImGui::IsItemHovered(ImGuiHoveredFlags_AllowWhenDisabled)) ImGui::SetTooltip("(With Uniform/Perceptual Color Space) The amount of new straighten blowout hue to blend onto the original.");
            DrawResetButton(cb_luma_global_settings.GameSettings.PCCHue, default_luma_global_game_settings.PCCHue, "PCCHue", runtime);

            ImGui::PushID("PCC: Chrom");
            if (ImGui::SliderFloat("Saturation Strength", &cb_luma_global_settings.GameSettings.PCCChrom, 0.f, 1.f, "%.3f"))
               reshade::set_config_value(runtime, NAME, "PCCChrom", cb_luma_global_settings.GameSettings.PCCChrom);
            ImGui::PopID();
            if (ImGui::IsItemHovered(ImGuiHoveredFlags_AllowWhenDisabled)) ImGui::SetTooltip("(With Uniform/Perceptual Color Space) The amount of new recovered chrominance to blend onto the original.");
            DrawResetButton(cb_luma_global_settings.GameSettings.PCCChrom, default_luma_global_game_settings.PCCChrom, "PCCChrom", runtime);
         }
      }
      
      static void SR(DeviceData& device_data, reshade::api::effect_runtime* runtime)
      {
         // Enabled? and HardReset
         if (!SR::IsOn())
         {
            ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(0.75f, 0.75f, 0.75f, 1.f));
            ImGui::TextWrapped("Super Resolution not on.");
            ImGui::PopStyleColor();
            ImGui::Bullet(); ImGui::SameLine(); ImGui::TextWrapped("Select it at the top to use this section.");
            return;
         }
         
         // In-Game Settings Requirements
         ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(1.f, 0.75f, 0.75f, 1.f));
         ImGui::TextWrapped("[NOTICE / REQUIREMENT]");
         ImGui::PopStyleColor();
         
         auto pulse = GetPulseMultiplier();
         auto colors = float3(1.f, 0.75f, 0.0f);
         auto colord = ImVec4(colors.x * pulse, colors.y * pulse, colors.z * pulse, 1.f);
         ImGui::PushStyleColor(ImGuiCol_Text, colord);
         ImGui::Bullet(); ImGui::SameLine(); ImGui::TextWrapped("Must be SMAA T2X (NOT FILMIC)!");
         ImGui::PopStyleColor();
         
         if (GameIdentity::game == GameIdentity::H1 || GameIdentity::game == GameIdentity::H2)
         {
            ImGui::Bullet(); ImGui::SameLine(); ImGui::TextWrapped("(MW1R & MW2R) Viewmodel is completely botched, broken motion vectors.\n(This is why unmodded SMAA Filmic has ghosting.)");
            ImGui::Bullet(); ImGui::SameLine(); ImGui::TextWrapped("(MW1R & MW2R) When Fullscreen Blur is drawn, the game disables SMAA, meaning this disables too.");
         }

         ImGui::Separator(); /////////////////////
         
         ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(0.75f, 0.75f, 1.f, 1.f));
         ImGui::TextWrapped("[Resolution Scaling]");
         ImGui::PopStyleColor();
         ImGui::Bullet(); ImGui::SameLine(); ImGui::TextWrapped("Responds to Internal/Render Resolution, where >100%% is untested.");
         if (ImGui::Button("Panic Reset")) SR::Buffers::HardReset();
         if (ImGui::IsItemHovered(ImGuiHoveredFlags_AllowWhenDisabled)) ImGui::SetTooltip("Trash all extra/auxiliary color buffers to recreate them next draw.");
         ImGui::SameLine(); ImGui::TextWrapped("%dp -> %dp (%d%%)", SR::Buffers::GetRenderResolution().y, static_cast<uint>(cb_luma_global_settings.SwapchainSize.y), std::lround(SR::Buffers::GetRenderRatio() * 100));

         ImGui::Separator(); /////////////////////
         
         // Additional Jitter Offsets
         ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(1.f, 1.f, 0.75f, 1.f));
         ImGui::TextWrapped("[Additional Jitter Phases]");
         ImGui::PopStyleColor();
         ImGui::Bullet(); ImGui::SameLine(); ImGui::TextWrapped("T2X only has 2 subpixel jitter offset/phases, which isn't enough.");
         if (SR::Jitter::IsReady())
         {
            if (DEVELOPMENT && ImGui::Button("Disarm")) SR::Jitter::TryDisarm(runtime);
            ImGui::SameLine();
            ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(0.75f, 1.f, 0.75f, 1.f));
            ImGui::Bullet(); ImGui::SameLine(); ImGui::TextWrapped("ACTIVE AND PATCHING, %d Phases (%.5f, %.5f)", SR::Jitter::phases_curr, SR::Jitter::jitter_curr.x, SR::Jitter::jitter_curr.y);
            ImGui::PopStyleColor();

            if (SR::IsOn())
            {
               auto pulse = GetPulseMultiplier();
               auto colors = float3(1.f, 0.75f, 0.0f);
               auto colord = ImVec4(colors.x * pulse, colors.y * pulse, colors.z * pulse, 1.f);
               ImGui::PushStyleColor(ImGuiCol_Text, colord);
               ImGui::Checkbox("Jitter Calibration (Read Tooltip)", &SR::Jitter::is_desynctest);
               ImGui::PopStyleColor();
               if (ImGui::IsItemHovered(ImGuiHoveredFlags_AllowWhenDisabled)) ImGui::SetTooltip("(Should be unneeded unless graphics settings are changed after boot.)\n\nEnabling will make jitter extreme!\nIf the whole world is shaking, toggle Flip Sync to fix the jitter desync.");

               if (!SR::Jitter::is_desynctest) ImGui::BeginDisabled();
               {
                  ImGui::Checkbox("Flip Sync", &SR::Jitter::is_flipsync);
                  if (ImGui::IsItemHovered(ImGuiHoveredFlags_AllowWhenDisabled)) ImGui::SetTooltip("(Paired with above. Enable it to change this.)\n\nThere are 2 jitter offset (hence T2X).\nEvery frame, we inject a new one.\nHowever, we can't override both; Only the offset that's up-next is safe to be replaced.");
               }
               if (!SR::Jitter::is_desynctest) ImGui::EndDisabled();
               
               if (DEVELOPMENT)
               {
                  ImGui::Spacing();
                  ImGui::Spacing();
                  
                  ImGui::SliderInt("Phases", reinterpret_cast<int*>(&SR::Jitter::phases_user), 0, 32);
                  if (ImGui::IsItemHovered(ImGuiHoveredFlags_AllowWhenDisabled)) ImGui::SetTooltip("Higher is not better, since it will take longer for the subpixel position to repeat.");
               
                  ImGui::Checkbox("Negative X", &SR::Jitter::is_neg_x);
                  ImGui::Checkbox("Negative Y", &SR::Jitter::is_neg_y);
                  ImGui::Checkbox("Use Previous Frame", &SR::Jitter::is_prev);
                  ImGui::Checkbox("Set Both", &SR::Jitter::is_setboth);
                  ImGui::Checkbox("Motion Vector Jittered", &SR::Jitter::is_mvjittered);
                  ImGui::Checkbox("T2X Jitter Mode", &SR::Jitter::is_t2xjitter);
                  
                  // ImGui::SliderFloat("Near Plane", &SR::draw_data.near_plane, 0.f, 1.f, "%.5f");
                  // ImGui::SliderFloat("Far Plane", &SR::draw_data.far_plane, 0.f, 1.f, "%.5f");
               }
            }
            
         }
         else
         {
            static bool failed = false;
            if (ImGui::Button("Scan for Jitter Address Offset")) failed = !SR::Jitter::SetAddressFromScanIfVerified(runtime);
            ImGui::SameLine(); ImGui::TextWrapped("(If you are seeing this, something went wrong. Please report!)");

            if (failed)
            {
               ImGui::PushStyleColor(ImGuiCol_Text, IM_COL32(255, 100, 100, 255));
               ImGui::Bullet(); ImGui::SameLine(); ImGui::TextWrapped("Failed to find jitter address offset! Please report!");
               ImGui::PopStyleColor();
            }
         }

         ImGui::Separator(); /////////////////////

         ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(1.0f, 0.75f, 1.f, 1.f));
         ImGui::TextWrapped("[Texture Sampler Upgrade]");
         ImGui::PopStyleColor();
         ImGui::Bullet(); ImGui::SameLine(); ImGui::TextWrapped("For sharper aggregation, texture sampling must be upgraded.");
         ImGui::Bullet(); ImGui::SameLine(); ImGui::TextWrapped("However, this will unintentionally bump up cubemap reflection sharpness, and causes other differences.");

         ImGui::PushID("SR Sampler Upgrade Bypass");
         ImGui::Checkbox("Bypass", &SR::ignore_upgraded_samplers_user);
         ImGui::PopID();
      }

      void PostProcessing(DeviceData& device_data, reshade::api::effect_runtime* runtime)
      {
         ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(1.f, 1.f, 0.75f, 1.f));
         ImGui::TextWrapped("Miscellaneous toggles and sliders.");
         ImGui::PopStyleColor();

         //Bloom cb
         ImGui::PushID("PP Bloom");
         if (ImGui::SliderFloat("Bloom", &cb_luma_global_settings.GameSettings.Bloom, 0.f, 2.f, "%.3f"))
            reshade::set_config_value(runtime, NAME, "Bloom", cb_luma_global_settings.GameSettings.Bloom);
         ImGui::PopID();
         if (ImGui::IsItemHovered(ImGuiHoveredFlags_AllowWhenDisabled)) ImGui::SetTooltip("Simple bloom intensity multiplier.");
         DrawResetButton(cb_luma_global_settings.GameSettings.Bloom, default_luma_global_game_settings.Bloom, "Bloom", runtime);

         //TODO more
         //TODO IW film grain

         ImGui::Separator(); /////////////////

         //AllowVanillaColorGrade
         {
            bool b = cb_luma_global_settings.GameSettings.AllowVanillaColorGrade > 0;
            if (ImGui::Checkbox("(Debug) Vanilla Color Grade", &b)) cb_luma_global_settings.GameSettings.AllowVanillaColorGrade = b ? 1.f : 0.f;
         }
         if (ImGui::IsItemHovered(ImGuiHoveredFlags_AllowWhenDisabled)) ImGui::SetTooltip("Allow the game's color grading effects like LUT, saturation, tint, etc.\nDisabling results in the raw per-channel blown out color without alterations.");
         
         //pipeline_is_ui checkbox
         ImGui::Checkbox("(Photo Mode) UI", &Globals::pipeline_is_ui);
         if (ImGui::IsItemHovered(ImGuiHoveredFlags_AllowWhenDisabled)) ImGui::SetTooltip("Can disable all draw calls after the scene image is drawn.");

         //AllowFullscreenBlur
         {
            bool b = cb_luma_global_settings.GameSettings.AllowFullscreenBlur > 0;
            if (ImGui::Checkbox("(Photo Mode) Fullscreen Blur", &b)) cb_luma_global_settings.GameSettings.AllowFullscreenBlur = b ? 1.f : 0.f;
         }
         if (ImGui::IsItemHovered(ImGuiHoveredFlags_AllowWhenDisabled)) ImGui::SetTooltip("Can bypass the blur shader, making it output the original unblurred scene color.");
     }
   }

   // section struct
   using SectionFunc = std::function<void(DeviceData&, reshade::api::effect_runtime*)>;
   struct SectionEntry { const char* name; SectionFunc draw; }; 

   // list of sections
   static inline std::vector<SectionEntry> sections =
   {
      {"README (Scroll Me!)",                 [](DeviceData& d, reshade::api::effect_runtime* r){ Templates::README(d, r); }},
      {"In-Game Settings: Warning",           [](DeviceData& d, reshade::api::effect_runtime* r){ Templates::InGameSettingsWarning(d, r); }},
      {"In-Game Settings: Brightness",        [](DeviceData& d, reshade::api::effect_runtime* r){ Templates::InGameSettingsBrightness(d, r); }},
      {"Gamma Correction",                    [](DeviceData& d, reshade::api::effect_runtime* r){ Templates::GammaCorrection(d, r); }},
      {"Super Resolution",                    [](DeviceData& d, reshade::api::effect_runtime* r){ Templates::SR(d, r); }},
      {"Luminance Extension",                 [](DeviceData& d, reshade::api::effect_runtime* r){ Templates::HDRBrightness(d, r); }},
      {"Chrominance Extension",               [](DeviceData& d, reshade::api::effect_runtime* r){ Templates::PerChannelCorrection(d, r); }},
      {"Post Processing / Miscellaneous",     [](DeviceData& d, reshade::api::effect_runtime* r){ Templates::PostProcessing(d, r); }},
   };
   
   //current section index
   static int index = 0;

   static void OnDrawContents(int i, DeviceData& device_data, reshade::api::effect_runtime* runtime)
   {
      if (i >= 0 && i < static_cast<int>(sections.size()) && sections[i].draw) //range & null check
         sections[i].draw(device_data, runtime);
   }

   static bool IndexGetMin() {return index <= 0;}
   static bool IndexGetMax() {return index >= static_cast<int>(sections.size()) - 1;}
   static void IndexSaveConfig(reshade::api::effect_runtime* runtime) {reshade::set_config_value(runtime, NAME, "SectionedImGuiIndex", index);}
   static void IndexLoadConfig(reshade::api::effect_runtime* runtime) {reshade::get_config_value(runtime, NAME, "SectionedImGuiIndex", index);}

   static void OnLoadConfigs(reshade::api::effect_runtime* runtime)
   {
      IndexLoadConfig(runtime);
   }
   
   static void OnDraw(reshade::api::effect_runtime* runtime, DeviceData& device_data)
   {      
      // index setup
      int index_prev = index;
      index = std::clamp(index, 0, static_cast<int>(sections.size()) - 1);
      
      // <-- button
      if (IndexGetMin()) ImGui::BeginDisabled();
      ImGui::PushID("SectionedImGui_Left");
      if (ImGui::ArrowButton("##left", ImGuiDir_Left)) index--;
      ImGui::PopID();
      if (IndexGetMin()) ImGui::EndDisabled();

      // current section dropdown
      ImGui::SameLine();
      ImGui::PushID("SectionedImGui_Combo");
      {
         const std::vector<const char*> section_names = [](){
            std::vector<const char*> names;
            for (const auto& s : sections) names.push_back(s.name);
            return names;
         }();
         ImGui::Combo("##SectionedImGui_Combo", &index, section_names.data(), static_cast<int>(section_names.size()));
         if (ImGui::IsItemHovered())
         {
            const float wheel = ImGui::GetIO().MouseWheel;
            if (wheel > 0.f) index--;
            else if (wheel < 0.f) index++;
            index = std::clamp(index, 0, static_cast<int>(sections.size()) - 1);
         }
      }
      ImGui::PopID();
      
      // --> button
      ImGui::SameLine();
      if (IndexGetMax()) ImGui::BeginDisabled();
      ImGui::PushID("SectionedImGui_Right");
      if (ImGui::ArrowButton("##right", ImGuiDir_Right)) index++;
      ImGui::PopID();
      if (IndexGetMax()) ImGui::EndDisabled();

      // Contents with bevel border
      ImGui::Spacing();
      ImGui::PushStyleColor(ImGuiCol_ChildBg, ImVec4(0.0f, 0.0f, 0.0f, 0.125f));
      ImGui::PushStyleColor(ImGuiCol_Border, ImVec4(0.0f, 0.0f, 0.0f, 0.0f));
      ImGui::PushStyleVar(ImGuiStyleVar_ChildRounding, 0.0f);
      ImGui::PushStyleVar(ImGuiStyleVar_WindowPadding, ImVec2(8.0f, 8.0f));
      ImGui::BeginChild("##SectionContents", ImVec2(0, 0), ImGuiChildFlags_AutoResizeY | ImGuiChildFlags_Borders);
      OnDrawContents(index, device_data, runtime); // Draw!
      ImGui::EndChild();
      {
         const ImVec2 min = ImGui::GetItemRectMin();
         const ImVec2 max = ImGui::GetItemRectMax();
         ImDrawList* dl   = ImGui::GetWindowDrawList();
         constexpr float r = 4.0f;
         dl->AddRect(min, max,
            IM_COL32(0, 0, 0, 180), r, 0, 2.f);
         dl->AddRect({min.x + 1.f, min.y + 1.f}, {max.x - 1.f, max.y - 1.f},
            IM_COL32(255, 255, 255, 25), r);
      }
      ImGui::PopStyleVar(2);
      ImGui::PopStyleColor(2);

      // Save index
      if (index_prev != index) IndexSaveConfig(runtime);
      
      // Forced, for stuff to always exec regardless of section
      sectioned_imgui->OnDrawContentsForced(device_data, runtime);
   }

   struct H1 final : public Base
   {
      void OnDllMain() override
      {
         
      }
      void OnDrawContentsForced(DeviceData& device_data, reshade::api::effect_runtime* runtime) override
      {
         Base::OnDrawContentsForced(device_data, runtime);
      }
   };

   struct H2 final : public Base
   {
      void OnDllMain() override
      {
         
      }
      void OnDrawContentsForced(DeviceData& device_data, reshade::api::effect_runtime* runtime) override
      {
         Base::OnDrawContentsForced(device_data, runtime);
      }
   };

   void OnDllMainAfterGameIdentity(GameIdentity::GameType game)
   {
      switch (game)
      {
         case GameIdentity::GameType::H1: sectioned_imgui = std::make_unique<H1>(); break;
         case GameIdentity::GameType::H2: sectioned_imgui = std::make_unique<H2>(); break;
         default: ASSERT_MSG(false, "(CODs::OnDllMainAfterGameIdentity()) FATAL ERROR, Unknown game!"); break;
      }
      sectioned_imgui->OnDllMain();
   }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

namespace CODs
{
   struct COD
   {
      virtual ~COD() = default;

      virtual void OnDllMain()
      {
         // Default
         texture_format_upgrades_type = TextureFormatUpgradesType::AllowedEnabled;
         texture_upgrade_formats = {
            reshade::api::format::r8g8b8a8_typeless,
            reshade::api::format::r8g8b8a8_unorm,
            reshade::api::format::r11g11b10_float,
            reshade::api::format::r8g8_snorm,
         };
         texture_format_upgrades_2d_size_filters = 0 | (uint32_t)TextureFormatUpgrades2DSizeFilters::SwapchainResolution | (uint32_t)TextureFormatUpgrades2DSizeFilters::SwapchainAspectRatio;
      }
      
      virtual void OnInitCBOverride() {}
      virtual void OnCreateDevice(ID3D11Device* native_device, DeviceData& device_data) {}
      virtual DrawOrDispatchOverrideType OnDrawOrDispatch(ID3D11Device* native_device, ID3D11DeviceContext* native_device_context, CommandListData& cmd_list_data, DeviceData& device_data, reshade::api::shader_stage stages, const ShaderHashesList<OneShaderPerPipeline>& original_shader_hashes, bool is_custom_pass, bool& updated_cbuffers, std::function<void()>* original_draw_dispatch_func) {return DrawOrDispatchOverrideType::None;}
      virtual void OnPresent(ID3D11Device* native_device, ID3D11DeviceContext* native_device_context, DeviceData& device_data) {}
   };
   inline std::unique_ptr<COD> cod;

   struct GameDeviceDataBase : GameDeviceData
   {
      // RTVState (when post processing output's RTV is backbuffer, the following are all UI.)
      enum RTVState
      {
         None,
         ToBackBuffer,
      };
      RTVState rtvstate = None;
      Globals::Buffer rtvstate_buffers;
      CustomPixelShaderPassData rtvstate_custompassdata = {};

      virtual void OnPresent(ID3D11Device* native_device, ID3D11DeviceContext* native_device_context, DeviceData& device_data)
      {
         // Reset
         rtvstate = None;
      }

      // Will fill out rtvstate_buffers
      bool OnDrawOrDispatch_HandleRTVState(ID3D11Device* native_device, ID3D11DeviceContext* native_device_context, DeviceData& device_data)
      {
         // RTV0
         {
            ID3D11RenderTargetView* p = nullptr;
            native_device_context->OMGetRenderTargets(1, &p, nullptr); //get
            rtvstate_buffers.rtv.reset(p); //take
         }
         [[unlikely]] if (!rtvstate_buffers.rtv) return false;
               
         // RTV0 Res
         {
            ID3D11Resource* p = nullptr;
            rtvstate_buffers.rtv->GetResource(&p); //get
            rtvstate_buffers.res.reset(p); //take
         }

         // O(n) check if one of back_buffers
         bool success = false;
         {
            const auto rtv0_resource_handle = reinterpret_cast<uint64_t>(rtvstate_buffers.res.get());
            for (const uint64_t bb_handle : device_data.back_buffers)
            {
               if (bb_handle == rtv0_resource_handle)
               {
                  success = true;
                  break;
               }
            }
         }
         
         return success;
      }
   };
   
   struct H1 final : public COD
   {
      struct GameDeviceDataH1 final : GameDeviceDataBase
      {
         bool drawn_depthcopy = false;
         bool drawn_motionvectors = false;
         bool drawn_rolloff = false;
         bool drawn_smaa = false;
         
         void OnPresent(ID3D11Device* native_device, ID3D11DeviceContext* native_device_context, DeviceData& device_data) override
         {
            GameDeviceDataBase::OnPresent(native_device, native_device_context, device_data);
            drawn_depthcopy = false;
            drawn_motionvectors = false;
            drawn_rolloff = false;
            drawn_smaa = false;
         }
      };
      
      void OnDllMain() override
      {
         COD::OnDllMain();

         //del "__h1Exe" file
         std::error_code ec;
         std::filesystem::remove("__h1Exe", ec);
      }

      void OnInitCBOverride() override
      {
         default_luma_global_game_settings.PCCPeak = cb_luma_global_settings.GameSettings.PCCPeak = 1.6156f;
         default_luma_global_game_settings.ExposurePost = cb_luma_global_settings.GameSettings.ExposurePost = 2.225f;
         default_luma_global_game_settings.ExposurePre = cb_luma_global_settings.GameSettings.ExposurePre = 1.0385f;
      }
      
      void OnCreateDevice(ID3D11Device* native_device, DeviceData& device_data) override
      {
         message(reshade::log::level::info, "(H1::OnCreateDevice()) Creating GameDeviceDataH1");
         device_data.game = new GameDeviceDataH1;
      }
      
      DrawOrDispatchOverrideType OnDrawOrDispatch(ID3D11Device* native_device, ID3D11DeviceContext* native_device_context, CommandListData& cmd_list_data, DeviceData& device_data, reshade::api::shader_stage stages, const ShaderHashesList<OneShaderPerPipeline>& original_shader_hashes, bool is_custom_pass, bool& updated_cbuffers, std::function<void()>* original_draw_dispatch_func) override
      {
         GameDeviceDataH1* game_device_data = static_cast<GameDeviceDataH1*>(device_data.game);
         DrawOrDispatchOverrideType result = DrawOrDispatchOverrideType::None;
         const uint64_t ps = original_shader_hashes.pixel_shaders[0];
         
         constexpr uint64_t hash_depthcopy = 0x21D41B88;
         constexpr uint64_t hash_motionvectors = 0x5ABE0D31;
         constexpr uint64_t hash_rolloff = 0x5BD08BA5;
         constexpr uint64_t hash_t2x = 0x70A7B390;
         constexpr uint64_t hash_t2xf = 0x8AC08A9D;
         constexpr std::array<uint64_t, 2> hashes_smaa_setup = { 0x2D7F75F2, 0x38E527BF };
         constexpr uint64_t hash_blit0 = 0x5DC4BC99;
         // constexpr uint64_t hash_blit1 = 0x69F5418B; //TODO: this is an UI shader, bruh what
         constexpr uint64_t hash_blit_blur = 0x2085E3DE;
         
         // case: depth copy
         if (!game_device_data->drawn_depthcopy && ps == hash_depthcopy)
         {
            game_device_data->drawn_depthcopy = true;
         
            // Store depth resource RTV0
            {
               ID3D11RenderTargetView* p = nullptr;
               native_device_context->OMGetRenderTargets(1, &p, nullptr); //get
               SR::Buffers::depth.rtv.reset(p); //take

               ID3D11Resource* p2 = nullptr;
               SR::Buffers::depth.rtv->GetResource(&p2); //get
               SR::Buffers::depth.res.reset(p2); //take
            }
            
            return DrawOrDispatchOverrideType::None; //subsequent is redundant
         }

         // case: generate motion vectors (the last one for world (opposed to dynamic))
         if (!game_device_data->drawn_motionvectors && ps == hash_motionvectors)
         {
            game_device_data->drawn_motionvectors = true;

            if (SR::IsOn())
            {
               // Store depth srv0 (if not already by depth copy)
               if (!game_device_data->drawn_depthcopy)
               {
                  ID3D11ShaderResourceView* p = nullptr;
                  native_device_context->PSGetShaderResources(2, 1, &p); //get
                  SR::Buffers::depth.srv.reset(p); //take

                  ID3D11Resource* p2 = nullptr;
                  SR::Buffers::depth.srv->GetResource(&p2); //get
                  SR::Buffers::depth.res.reset(p2); //take
               }

               // // Store motion vectors rtv0
               // {
               //    ID3D11RenderTargetView* p = nullptr;
               //    native_device_context->OMGetRenderTargets(1, &p, nullptr); //get
               //    SR::Buffers::motionvectors.rtv.reset(p); //take
               //
               //    ID3D11Resource* p2 = nullptr;
               //    SR::Buffers::motionvectors.rtv->GetResource(&p2); //get
               //    SR::Buffers::motionvectors.res.reset(p2); //take
               //
               //    //TODO: make srv?
               // }
            }
            
            return DrawOrDispatchOverrideType::None; //subsequent is redundant
         }

         // case: rolloff shader
         if (!game_device_data->drawn_rolloff && ps == hash_rolloff)
         {
            game_device_data->drawn_rolloff = true;
            return DrawOrDispatchOverrideType::None; //subsequent is redundant
         }

         // case: skip SMAA T2x setup when SR
         if (SR::IsOn() && game_device_data->drawn_rolloff && !game_device_data->drawn_smaa
            && std::ranges::find(hashes_smaa_setup, ps) != hashes_smaa_setup.end())
         {
            return DrawOrDispatchOverrideType::Skip; //subsequent is redundant
         }

         // handle: RTVState & case: UI because ToBackBuffer
         bool is_rtv_to_backbuffer_started_this_frame = false;
         switch (game_device_data->rtvstate)
         {
            case GameDeviceDataBase::RTVState::None:
            {
               // Fail?
               if (!game_device_data->drawn_rolloff) break;
               if (ps == 0) break;
               if (!game_device_data->OnDrawOrDispatch_HandleRTVState(native_device, native_device_context, device_data)) break;
                  
               // Success ////////////////////////////////////////////////////////////
               game_device_data->rtvstate = GameDeviceDataBase::RTVState::ToBackBuffer;
               is_rtv_to_backbuffer_started_this_frame = true;

               // reset SR state
               device_data.has_drawn_sr = false;

               // Unexpected
               if (ps != hash_t2x && ps != hash_t2xf && ps != hash_blit0 && ps != hash_blit_blur) 
               {
                  auto s = std::format("Unexpected shader hash when handling RTVState transition: {:#x}", ps);
                  message(reshade::log::level::error, s.c_str());
                  ASSERT_ONCE_MSG(false, s + "\nPlease report bug!");
               }
               
               break;
            }
            case GameDeviceDataBase::RTVState::ToBackBuffer:
            {
               // UI Toggle
               if (!Globals::pipeline_is_ui) result = DrawOrDispatchOverrideType::Skip;
               
               break;
            }
         }

         // case: FAILED SMAA T2x Filmic resolve (and it comes after T2x resolve)
         if (SR::IsOn() && ps == hash_t2xf)
         {
            ASSERT_ONCE_MSG(false, "Don't use Filmic!\nUse normal SMAA T2X!");
            return DrawOrDispatchOverrideType::Skip;
         }
         
         // case: SR for SMAA T2x
         if (SR::IsOn() && !game_device_data->drawn_smaa && ps == hash_t2x)
         {
            game_device_data->drawn_smaa = true;
            
            // sr_instance_data
            auto* sr_instance_data = device_data.GetSRInstanceData();
            if (DEVELOPMENT && !sr_instance_data)
            {
               ASSERT_ONCE_MSG(false, "sr_instance_data is null!?!?!");
               return DrawOrDispatchOverrideType::Skip;
            }
         
            // FAILED: couldn't find depth resource
            if (!game_device_data->drawn_motionvectors && !game_device_data->drawn_depthcopy)
            {
               auto sf = std::format("The depth resource could not be found this frame.\nThis should never happen, so please report!\n(motionvectors: {}, depthcopy: {})", game_device_data->drawn_motionvectors, game_device_data->drawn_depthcopy);
               ASSERT_ONCE_MSG(false, sf);
               message(reshade::log::level::error, sf.c_str());
         
               // last hurrah?
               if (!SR::Buffers::depth.res) return DrawOrDispatchOverrideType::Skip;
            }
            
            // color_in
            uint2 render_res;
            {
               // SR::Buffers::color_in.srv = dss.state->shader_resource_views[i];
               ID3D11ShaderResourceView* p = nullptr;
               native_device_context->PSGetShaderResources(2, 1, &p);
               SR::Buffers::color_in.srv.reset(p);
               if (DEVELOPMENT) ASSERT(SR::Buffers::color_in.srv != nullptr); //impossible
               
               ID3D11Resource* p2 = nullptr;
               SR::Buffers::color_in.srv->GetResource(&p2);
               SR::Buffers::color_in.res.reset(p2);
         
               ID3D11Texture2D* p3 = nullptr;
               auto hr = SR::Buffers::color_in.res->QueryInterface(&p3);
               if (DEVELOPMENT) ASSERT_ONCE(SUCCEEDED(hr));
               SR::Buffers::color_in.tex.reset(p3);
               
               SR::Buffers::color_in.tex->GetDesc(&SR::Buffers::color_in.desc);
         
               render_res = uint2(SR::Buffers::color_in.desc.Width, SR::Buffers::color_in.desc.Height);
            }
         
            // motionvectors
            {
               // SR::Buffers::motionvectors.srv = dss.state->shader_resource_views[i];
               ID3D11ShaderResourceView* p = nullptr;
               native_device_context->PSGetShaderResources(7, 1, &p);
               SR::Buffers::motionvectors.srv.reset(p);
               if (DEVELOPMENT) ASSERT(SR::Buffers::motionvectors.srv != nullptr); //impossible
         
               ID3D11Resource* p2 = nullptr;
               SR::Buffers::motionvectors.srv->GetResource(&p2);
               SR::Buffers::motionvectors.res.reset(p2);
            }
            
            // color_out dirty?
            uint2 output_res = uint2(cb_luma_global_settings.SwapchainSize.x, cb_luma_global_settings.SwapchainSize.y);
            output_res = uint2(max(output_res.x, render_res.x), max(output_res.y, render_res.y)); // account for >100%
            bool color_out_dirty = false;
            {
               // dirty: not ready
               if (!SR::Buffers::IsReady())
               {
                  color_out_dirty = true;
                  goto AfterColorOutDirtyCheck;
               }
            
               // FAILED: too small
               if (render_res.x < sr_instance_data->min_resolution || render_res.y < sr_instance_data->min_resolution)
                  return DrawOrDispatchOverrideType::Skip;
               
               // dirty: render res changed
               uint2 color_out_res = uint2(SR::Buffers::color_out.desc.Width, SR::Buffers::color_out.desc.Height);
               if (output_res.x != color_out_res.x || output_res.y != color_out_res.y)
               {
                  color_out_dirty = true;
                  goto AfterColorOutDirtyCheck;
               }
            }
            AfterColorOutDirtyCheck:
            
            // create all needed buffers
            if (color_out_dirty)
            {
               SR::Buffers::Create(native_device, render_res, output_res);
               message(reshade::log::level::info, std::format("(H1::OnDrawOrDispatch()) Created/Updated SR buffers {}", SR::Buffers::GetRenderRatio()).c_str());
            }
         
            // RETURN: must hold out on SR draw ///////////////////////////////////////
            if (!is_rtv_to_backbuffer_started_this_frame)
            {
               if (DEVELOPMENT) ASSERT(!SR::Buffers::IsNativeResolution()); //impossible
               
               //replace SMAA T2x with blit
               auto ps_skip = device_data.native_pixel_shaders.find(CompileTimeStringHash(NativeShaders::Luma_h1_SMAAT2XSkip_PS));
               if (ps_skip == device_data.native_pixel_shaders.end() || !ps_skip->second.get()) return DrawOrDispatchOverrideType::Skip;
               native_device_context->PSSetShader(ps_skip->second.get(), nullptr, 0);
               
               return DrawOrDispatchOverrideType::None;
            }
            
            // cache state
            DrawDav::DrawStateStack<DrawDav::DrawStateStackType::SimpleGraphics> dss; //w/o SRV cache, since it crashes game... somehow
            dss.Cache(native_device_context, 0);
               
            // FAILED: vs not found
            auto vs = device_data.native_vertex_shaders.find(CompileTimeStringHash("Copy VS"));
            if (vs == device_data.native_vertex_shaders.end() || !vs->second.get())
            {
               dss.Restore(native_device_context);
               return DrawOrDispatchOverrideType::Skip;
            }
            
            // FAILED: Luma_h1_SRMotionVectorIn_PS not found
            auto ps0 = device_data.native_pixel_shaders.find(CompileTimeStringHash(NativeShaders::Luma_h1_SRMotionVectorIn_PS));
            if (ps0 == device_data.native_pixel_shaders.end() || !ps0->second.get()) 
            {
               dss.Restore(native_device_context);
               return DrawOrDispatchOverrideType::Skip;
            }
            
            // motion vectors: draw (and its setup)
            DrawCustomPixelShader(native_device_context, nullptr, nullptr, nullptr, vs->second.get(), ps0->second.get(),
               SR::Buffers::motionvectors.srv.get(), SR::Buffers::motionvectors_linear.rtv.get(), SR::Buffers::motionvectors_linear.desc.Width, SR::Buffers::motionvectors_linear.desc.Height);
            
            // FAILED: Luma_h1_SRColorIn_PS not found
            auto ps1 = device_data.native_pixel_shaders.find(CompileTimeStringHash(NativeShaders::Luma_h1_SRColorIn_PS));
            if (ps1 == device_data.native_pixel_shaders.end() || !ps1->second.get()) 
            {
               dss.Restore(native_device_context);
               return DrawOrDispatchOverrideType::Skip;
            }
            
            // color in: draw linearize
            DrawCustomPixelShader(native_device_context, nullptr, nullptr, nullptr, vs->second.get(), ps1->second.get(),
               SR::Buffers::color_in.srv.get(), SR::Buffers::color_in_linear.rtv.get(), SR::Buffers::color_in_linear.desc.Width, SR::Buffers::color_in_linear.desc.Height);
         
            // SR!
            device_data.has_drawn_sr = SR::Draw(device_data, native_device_context, sr_instance_data, render_res, output_res,
               SR::Buffers::depth.res.get(), SR::Buffers::motionvectors_linear.res.get(), SR::Buffers::color_in_linear.res.get(), SR::Buffers::color_out.res.get());
         
            // FAILED: SR failed!!!
            if (!device_data.has_drawn_sr)
            {
               ASSERT_ONCE_MSG(false, "SR failed to draw!");
               dss.Restore(native_device_context);
               device_data.force_reset_sr = true;
               return DrawOrDispatchOverrideType::Replaced;
            }
         
            // FAILED: Luma_h1_SRColorOut_PS not found
            auto ps2 = device_data.native_pixel_shaders.find(CompileTimeStringHash(NativeShaders::Luma_h1_SRColorOut_PS));
            if (ps2 == device_data.native_pixel_shaders.end() || !ps2->second.get())
            {
               dss.Restore(native_device_context);
               return DrawOrDispatchOverrideType::Skip;
            }
            
            // color out linearize/copy: draw
            DrawCustomPixelShader(native_device_context, nullptr, nullptr, /*device_data.sampler_state_point.get()*/ nullptr, vs->second.get(), ps2->second.get(),
               SR::Buffers::color_out.srv.get(), game_device_data->rtvstate_buffers.rtv.get(), SR::Buffers::color_out.desc.Width, SR::Buffers::color_out.desc.Height);
            
            // restore state
            dss.Restore(native_device_context);
         
            return DrawOrDispatchOverrideType::Replaced;
         }
         
         // case: SR blit to backbuffer
         if (SR::IsOn() && !SR::Buffers::IsNativeResolution() && is_rtv_to_backbuffer_started_this_frame)
         {
            // cache state
            DrawDav::DrawStateStack<DrawDav::DrawStateStackType::SimpleGraphics> dss; //w/o SRV cache, since it crashes game... somehow
            dss.Cache(native_device_context, 0);
         
            // SPECIAL RETURN: SMAA T2x didn't draw, so SR is redundant (e.g. blur pass)
            if (!game_device_data->drawn_smaa)
            {
               if (DEVELOPMENT) ASSERT(ps == hash_blit_blur); //the only expected, but let's see...
         
               // orig
               original_draw_dispatch_func->operator()();
         
               // insert
               DrawCustomPixelShaderPass(native_device, native_device_context,
                  game_device_data->rtvstate_buffers.rtv.get(), device_data,
                  CompileTimeStringHash(NativeShaders::Luma_h1_RenderIntermediatePass_PS), game_device_data->rtvstate_custompassdata);
         
               // restore
               dss.Restore(native_device_context);
               
               return DrawOrDispatchOverrideType::Replaced;
            }
         
            // sr_instance_data
            auto* sr_instance_data = device_data.GetSRInstanceData();
            if (DEVELOPMENT && !sr_instance_data)
            {
               ASSERT_ONCE_MSG(false, "sr_instance_data is null!?!?!");
               return DrawOrDispatchOverrideType::Skip;
            }
            
            // replace color_in with srv4 (hash_blit0, hash_blit_blur)
            {
               ID3D11ShaderResourceView* p1 = nullptr;
               native_device_context->PSGetShaderResources(4, 1, &p1);
               SR::Buffers::color_in.srv.reset(p1);
               if (DEVELOPMENT) ASSERT(SR::Buffers::color_in.srv != nullptr); //impossible
         
               ID3D11Resource* p2 = nullptr;
               SR::Buffers::color_in.srv->GetResource(&p2);
               SR::Buffers::color_in.res.reset(p2);
            }
            
            //TODO: reduce copy paste!
         
            // FAILED: vs not found
            auto vs = device_data.native_vertex_shaders.find(CompileTimeStringHash("Copy VS"));
            if (vs == device_data.native_vertex_shaders.end() || !vs->second.get())
            {
               dss.Restore(native_device_context);
               return DrawOrDispatchOverrideType::Skip;
            }
            
            // FAILED: Luma_h1_SRMotionVectorIn_PS not found
            auto ps0 = device_data.native_pixel_shaders.find(CompileTimeStringHash(NativeShaders::Luma_h1_SRMotionVectorIn_PS));
            if (ps0 == device_data.native_pixel_shaders.end() || !ps0->second.get()) 
            {
               dss.Restore(native_device_context);
               return DrawOrDispatchOverrideType::Skip;
            }
            
            // motion vectors: draw linearize
            DrawCustomPixelShader(native_device_context, nullptr, nullptr, nullptr, vs->second.get(), ps0->second.get(),
               SR::Buffers::motionvectors.srv.get(), SR::Buffers::motionvectors_linear.rtv.get(), SR::Buffers::motionvectors_linear.desc.Width, SR::Buffers::motionvectors_linear.desc.Height);
            
            // FAILED: Luma_h1_SRColorIn_PS not found
            auto ps1 = device_data.native_pixel_shaders.find(CompileTimeStringHash(NativeShaders::Luma_h1_SRColorIn_PS));
            if (ps1 == device_data.native_pixel_shaders.end() || !ps1->second.get()) 
            {
               dss.Restore(native_device_context);
               return DrawOrDispatchOverrideType::Skip;
            }
            
            // color in: draw linearize
            DrawCustomPixelShader(native_device_context, nullptr, nullptr, nullptr, vs->second.get(), ps1->second.get(),
               SR::Buffers::color_in.srv.get(), SR::Buffers::color_in_linear.rtv.get(), SR::Buffers::color_in_linear.desc.Width, SR::Buffers::color_in_linear.desc.Height);
         
            // SR!
            device_data.has_drawn_sr = SR::Draw(device_data, native_device_context, sr_instance_data, SR::Buffers::color_in.GetDimensions(), SR::Buffers::color_out.GetDimensions(),
               SR::Buffers::depth.res.get(), SR::Buffers::motionvectors_linear.res.get(), SR::Buffers::color_in_linear.res.get(), SR::Buffers::color_out.res.get());
         
            // FAILED: SR failed!!!
            if (!device_data.has_drawn_sr)
            {
               ASSERT_ONCE_MSG(false, "SR failed to draw!");
               dss.Restore(native_device_context);
               device_data.force_reset_sr = true;
               return DrawOrDispatchOverrideType::Replaced;
            }
         
            // FAILED: Luma_h1_SRColorOut_PS not found
            auto ps2 = device_data.native_pixel_shaders.find(CompileTimeStringHash(NativeShaders::Luma_h1_SRColorOut_PS));
            if (ps2 == device_data.native_pixel_shaders.end() || !ps2->second.get())
            {
               dss.Restore(native_device_context);
               return DrawOrDispatchOverrideType::Skip;
            }
            
            // color out linearize/copy: draw
            DrawCustomPixelShader(native_device_context, nullptr, nullptr, /*device_data.sampler_state_point.get()*/ nullptr, vs->second.get(), ps2->second.get(),
               SR::Buffers::color_out.srv.get(), game_device_data->rtvstate_buffers.rtv.get(), SR::Buffers::color_out.desc.Width, SR::Buffers::color_out.desc.Height);
            
            // restore state
            dss.Restore(native_device_context);
         
            return DrawOrDispatchOverrideType::Replaced;
         }
         
         // case: even after all of that, we still haven't drawn RenderIntermediatePass, so do it now (e.g. when SR is off)
         if (!device_data.has_drawn_sr && is_rtv_to_backbuffer_started_this_frame)
         {
            // Draw original
            original_draw_dispatch_func->operator()();
            
            // RenderIntermediatePass on rtv / backbuffer
            {
               // Cache
               DrawDav::DrawStateStack<DrawDav::DrawStateStackType::SimpleGraphics> dss; //w/o SRV cache
               dss.Cache(native_device_context, 0);
            
               // Insert/Draw
               DrawCustomPixelShaderPass(native_device, native_device_context,
                  game_device_data->rtvstate_buffers.rtv.get(), device_data,
                  CompileTimeStringHash(NativeShaders::Luma_h1_RenderIntermediatePass_PS), game_device_data->rtvstate_custompassdata);
            
               // Restore
               dss.Restore(native_device_context);
            }
         
            return DrawOrDispatchOverrideType::Replaced;
         }
         
         return result;
      }
      
      void OnPresent(ID3D11Device* native_device, ID3D11DeviceContext* native_device_context, DeviceData& device_data) override
      {
         GameDeviceDataH1* game_device_data = static_cast<GameDeviceDataH1*>(device_data.game);
         game_device_data->OnPresent(native_device, native_device_context, device_data);
      }
   };

   struct H2 final : public COD
   {
      struct GameDeviceDataH2 final : GameDeviceDataBase
      {
         bool drawn_depthcopy = false;
         bool drawn_motionvectors = false;
         bool drawn_tonemap = false;
         bool drawn_smaa = false;
         
         void OnPresent(ID3D11Device* native_device, ID3D11DeviceContext* native_device_context, DeviceData& device_data) override
         {
            GameDeviceDataBase::OnPresent(native_device, native_device_context, device_data);
            drawn_depthcopy = false;
            drawn_motionvectors = false;
            drawn_tonemap = false;
            drawn_smaa = false;
         }
      };

      void OnInitCBOverride() override
      {
         default_luma_global_game_settings.PCCPeak = cb_luma_global_settings.GameSettings.PCCPeak = 3.875f;
      }
      
      void OnDllMain() override
      {
         COD::OnDllMain();

         //del "__h2Exe" file
         std::error_code ec;
         std::filesystem::remove("__h2Exe", ec);
      }
      
      void OnCreateDevice(ID3D11Device* native_device, DeviceData& device_data) override
      {
         message(reshade::log::level::info, "(H2::OnCreateDevice()) Creating GameDeviceDataH2");
         device_data.game = new H2::GameDeviceDataH2;
      }
      
      DrawOrDispatchOverrideType OnDrawOrDispatch(ID3D11Device* native_device, ID3D11DeviceContext* native_device_context, CommandListData& cmd_list_data, DeviceData& device_data, reshade::api::shader_stage stages, const ShaderHashesList<OneShaderPerPipeline>& original_shader_hashes, bool is_custom_pass, bool& updated_cbuffers, std::function<void()>* original_draw_dispatch_func) override
      {
         GameDeviceDataH2* game_device_data = static_cast<GameDeviceDataH2*>(device_data.game);
         DrawOrDispatchOverrideType result = DrawOrDispatchOverrideType::None;
         uint64_t ps = original_shader_hashes.pixel_shaders[0];

         constexpr uint64_t hash_depthcopy = 0x21D41B88;
         constexpr uint64_t hash_motionvectors = 0x5ABE0D31;
         constexpr std::array<uint64_t, 4> hashes_tonemap = { 0xD981F82B, 0x02A618A0, 0xA4860451, 0xC8C49F5D }; //TODO: detect more
         constexpr uint64_t hash_t2x = 0x9409928E;
         constexpr uint64_t hash_t2xf = 0x6AFEB085;
         constexpr std::array<uint64_t, 2> hashes_smaa_setup = { 0x2D7F75F2, 0x2068D0D2 };
         constexpr uint64_t hash_blit0 = 0x5DC4BC99;
         // constexpr uint64_t hash_blit1 = 0x69F5418B; //TODO: this is an UI shader, bruh what
         constexpr uint64_t hash_blit_blur = 0x2085E3DE;

         // case: depth copy
         if (!game_device_data->drawn_depthcopy && ps == hash_depthcopy)
         {
            game_device_data->drawn_depthcopy = true;
         
            // Store depth resource RTV0
            {
               ID3D11RenderTargetView* p = nullptr;
               native_device_context->OMGetRenderTargets(1, &p, nullptr); //get
               SR::Buffers::depth.rtv.reset(p); //take

               ID3D11Resource* p2 = nullptr;
               SR::Buffers::depth.rtv->GetResource(&p2); //get
               SR::Buffers::depth.res.reset(p2); //take
            }
            
            return DrawOrDispatchOverrideType::None; //subsequent is redundant
         }

         // case: generate motion vectors (the last one for world (opposed to dynamic))
         if (!game_device_data->drawn_motionvectors && ps == hash_motionvectors)
         {
            game_device_data->drawn_motionvectors = true;

            if (SR::IsOn())
            {
               // Store depth srv0 (if not already by depth copy)
               if (!game_device_data->drawn_depthcopy)
               {
                  ID3D11ShaderResourceView* p = nullptr;
                  native_device_context->PSGetShaderResources(2, 1, &p); //get
                  SR::Buffers::depth.srv.reset(p); //take

                  ID3D11Resource* p2 = nullptr;
                  SR::Buffers::depth.srv->GetResource(&p2); //get
                  SR::Buffers::depth.res.reset(p2); //take
               }

               // // Store motion vectors rtv0
               // {
               //    ID3D11RenderTargetView* p = nullptr;
               //    native_device_context->OMGetRenderTargets(1, &p, nullptr); //get
               //    SR::Buffers::motionvectors.rtv.reset(p); //take
               //
               //    ID3D11Resource* p2 = nullptr;
               //    SR::Buffers::motionvectors.rtv->GetResource(&p2); //get
               //    SR::Buffers::motionvectors.res.reset(p2); //take
               //
               //    //TODO: make srv?
               // }
            }
            
            return DrawOrDispatchOverrideType::None; //subsequent is redundant
         }

         // case: tonemap shader
         if (!game_device_data->drawn_tonemap && std::ranges::find(hashes_tonemap, ps) != hashes_tonemap.end())
         {
            game_device_data->drawn_tonemap = true;
            return DrawOrDispatchOverrideType::None; //subsequent is redundant
         }

         // case: skip SMAA T2x setup when SR
         if (SR::IsOn() && game_device_data->drawn_tonemap && !game_device_data->drawn_smaa
            && std::ranges::find(hashes_smaa_setup, ps) != hashes_smaa_setup.end())
         {
            return DrawOrDispatchOverrideType::Skip; //subsequent is redundant
         }

         // handle: RTVState & case: UI because ToBackBuffer
         bool is_rtv_to_backbuffer_started_this_frame = false;
         switch (game_device_data->rtvstate)
         {
            case GameDeviceDataBase::RTVState::None:
            {
               // Fail?
               if (ps == 0) break;
               if (!game_device_data->OnDrawOrDispatch_HandleRTVState(native_device, native_device_context, device_data)) break;
                     
               // Success ////////////////////////////////////////////////////////////
               game_device_data->rtvstate = GameDeviceDataBase::RTVState::ToBackBuffer;
               is_rtv_to_backbuffer_started_this_frame = true;

               // reset SR state
               device_data.has_drawn_sr = false;

               // set of all encountered shaders
               if (DEVELOPMENT)
               {
                  static std::unordered_set<uint64_t> encountered_shader_hashes = { 0x69f5418b, 0x2085e3de, 0x6AFEB085 };
                  if (encountered_shader_hashes.insert(ps).second) //true if new insertion
                  {
                     auto s = std::format("RTVState transition encountered new shader: {:#x}", ps);
                     // ASSERT_MSG(false, s + "\nPlease report this new shader hash!");
                     message(reshade::log::level::info, s.c_str());
                  }
               }
               
               break;
            }
            case GameDeviceDataBase::RTVState::ToBackBuffer:
            {
               // UI Toggle
               if (!Globals::pipeline_is_ui) result = DrawOrDispatchOverrideType::Skip;
                  
               break;
            }
         }

         // case: FAILED SMAA T2x Filmic resolve (and it comes after T2x resolve)
         if (SR::IsOn() && ps == hash_t2xf)
         {
            ASSERT_ONCE_MSG(false, "Don't use Filmic!\nUse normal SMAA T2X!");
            return DrawOrDispatchOverrideType::Skip;
         }
         
         // case: SR for SMAA T2x
         if (SR::IsOn() && !game_device_data->drawn_smaa && ps == hash_t2x)
         {
            game_device_data->drawn_smaa = true;
            
            // sr_instance_data
            auto* sr_instance_data = device_data.GetSRInstanceData();
            if (DEVELOPMENT && !sr_instance_data)
            {
               ASSERT_ONCE_MSG(false, "sr_instance_data is null!?!?!");
               return DrawOrDispatchOverrideType::Skip;
            }
         
            // FAILED: couldn't find depth resource
            if (!game_device_data->drawn_motionvectors && !game_device_data->drawn_depthcopy)
            {
               auto sf = std::format("The depth resource could not be found this frame.\nThis should never happen, so please report!\n(motionvectors: {}, depthcopy: {})", game_device_data->drawn_motionvectors, game_device_data->drawn_depthcopy);
               ASSERT_ONCE_MSG(false, sf);
               message(reshade::log::level::error, sf.c_str());
         
               // last hurrah?
               if (!SR::Buffers::depth.res) return DrawOrDispatchOverrideType::Skip;
            }
            
            // color_in
            uint2 render_res;
            {
               // SR::Buffers::color_in.srv = dss.state->shader_resource_views[i];
               ID3D11ShaderResourceView* p = nullptr;
               native_device_context->PSGetShaderResources(2, 1, &p);
               SR::Buffers::color_in.srv.reset(p);
               if (DEVELOPMENT) ASSERT(SR::Buffers::color_in.srv != nullptr); //impossible
               
               ID3D11Resource* p2 = nullptr;
               SR::Buffers::color_in.srv->GetResource(&p2);
               SR::Buffers::color_in.res.reset(p2);
         
               ID3D11Texture2D* p3 = nullptr;
               auto hr = SR::Buffers::color_in.res->QueryInterface(&p3);
               if (DEVELOPMENT) ASSERT_ONCE(SUCCEEDED(hr));
               SR::Buffers::color_in.tex.reset(p3);
               
               SR::Buffers::color_in.tex->GetDesc(&SR::Buffers::color_in.desc);
         
               render_res = uint2(SR::Buffers::color_in.desc.Width, SR::Buffers::color_in.desc.Height);
            }
         
            // motionvectors
            {
               // SR::Buffers::motionvectors.srv = dss.state->shader_resource_views[i];
               ID3D11ShaderResourceView* p = nullptr;
               native_device_context->PSGetShaderResources(7, 1, &p);
               SR::Buffers::motionvectors.srv.reset(p);
               if (DEVELOPMENT) ASSERT(SR::Buffers::motionvectors.srv != nullptr); //impossible
         
               ID3D11Resource* p2 = nullptr;
               SR::Buffers::motionvectors.srv->GetResource(&p2);
               SR::Buffers::motionvectors.res.reset(p2);
            }
            
            // color_out dirty?
            uint2 output_res = uint2(cb_luma_global_settings.SwapchainSize.x, cb_luma_global_settings.SwapchainSize.y);
            output_res = uint2(max(output_res.x, render_res.x), max(output_res.y, render_res.y)); // account for >100%
            bool color_out_dirty = false;
            {
               // dirty: not ready
               if (!SR::Buffers::IsReady())
               {
                  color_out_dirty = true;
                  goto AfterColorOutDirtyCheck;
               }
            
               // FAILED: too small
               if (render_res.x < sr_instance_data->min_resolution || render_res.y < sr_instance_data->min_resolution)
                  return DrawOrDispatchOverrideType::Skip;
               
               // dirty: render res changed
               uint2 color_out_res = uint2(SR::Buffers::color_out.desc.Width, SR::Buffers::color_out.desc.Height);
               if (output_res.x != color_out_res.x || output_res.y != color_out_res.y)
               {
                  color_out_dirty = true;
                  goto AfterColorOutDirtyCheck;
               }
            }
            AfterColorOutDirtyCheck:
            
            // create all needed buffers
            if (color_out_dirty)
            {
               SR::Buffers::Create(native_device, render_res, output_res);
               message(reshade::log::level::info, std::format("(H1::OnDrawOrDispatch()) Created/Updated SR buffers {}", SR::Buffers::GetRenderRatio()).c_str());
            }
         
            // RETURN: must hold out on SR draw ///////////////////////////////////////
            if (!is_rtv_to_backbuffer_started_this_frame)
            {
               if (DEVELOPMENT) ASSERT(!SR::Buffers::IsNativeResolution()); //impossible
               
               //replace SMAA T2x with blit
               auto ps_skip = device_data.native_pixel_shaders.find(CompileTimeStringHash(NativeShaders::Luma_h1_SMAAT2XSkip_PS));
               if (ps_skip == device_data.native_pixel_shaders.end() || !ps_skip->second.get()) return DrawOrDispatchOverrideType::Skip;
               native_device_context->PSSetShader(ps_skip->second.get(), nullptr, 0);
               
               return DrawOrDispatchOverrideType::None;
            }
            
            // cache state
            DrawDav::DrawStateStack<DrawDav::DrawStateStackType::SimpleGraphics> dss; //w/o SRV cache, since it crashes game... somehow
            dss.Cache(native_device_context, 0);
               
            // FAILED: vs not found
            auto vs = device_data.native_vertex_shaders.find(CompileTimeStringHash("Copy VS"));
            if (vs == device_data.native_vertex_shaders.end() || !vs->second.get())
            {
               dss.Restore(native_device_context);
               return DrawOrDispatchOverrideType::Skip;
            }
            
            // FAILED: Luma_h1_SRMotionVectorIn_PS not found
            auto ps0 = device_data.native_pixel_shaders.find(CompileTimeStringHash(NativeShaders::Luma_h1_SRMotionVectorIn_PS));
            if (ps0 == device_data.native_pixel_shaders.end() || !ps0->second.get()) 
            {
               dss.Restore(native_device_context);
               return DrawOrDispatchOverrideType::Skip;
            }
            
            // motion vectors: draw linearize
            DrawCustomPixelShader(native_device_context, nullptr, nullptr, nullptr, vs->second.get(), ps0->second.get(),
               SR::Buffers::motionvectors.srv.get(), SR::Buffers::motionvectors_linear.rtv.get(), SR::Buffers::motionvectors_linear.desc.Width, SR::Buffers::motionvectors_linear.desc.Height);
            
            // FAILED: Luma_h1_SRColorIn_PS not found
            auto ps1 = device_data.native_pixel_shaders.find(CompileTimeStringHash(NativeShaders::Luma_h1_SRColorIn_PS));
            if (ps1 == device_data.native_pixel_shaders.end() || !ps1->second.get()) 
            {
               dss.Restore(native_device_context);
               return DrawOrDispatchOverrideType::Skip;
            }
            
            // color in: draw linearize
            DrawCustomPixelShader(native_device_context, nullptr, nullptr, nullptr, vs->second.get(), ps1->second.get(),
               SR::Buffers::color_in.srv.get(), SR::Buffers::color_in_linear.rtv.get(), SR::Buffers::color_in_linear.desc.Width, SR::Buffers::color_in_linear.desc.Height);
         
            // SR!
            device_data.has_drawn_sr = SR::Draw(device_data, native_device_context, sr_instance_data, render_res, output_res,
               SR::Buffers::depth.res.get(), SR::Buffers::motionvectors_linear.res.get(), SR::Buffers::color_in_linear.res.get(), SR::Buffers::color_out.res.get());
         
            // FAILED: SR failed!!!
            if (!device_data.has_drawn_sr)
            {
               ASSERT_ONCE_MSG(false, "SR failed to draw!");
               dss.Restore(native_device_context);
               device_data.force_reset_sr = true;
               return DrawOrDispatchOverrideType::Replaced;
            }
         
            // FAILED: Luma_h1_SRColorOut_PS not found
            auto ps2 = device_data.native_pixel_shaders.find(CompileTimeStringHash(NativeShaders::Luma_h1_SRColorOut_PS));
            if (ps2 == device_data.native_pixel_shaders.end() || !ps2->second.get())
            {
               dss.Restore(native_device_context);
               return DrawOrDispatchOverrideType::Skip;
            }
            
            // color out linearize/copy: draw
            DrawCustomPixelShader(native_device_context, nullptr, nullptr, /*device_data.sampler_state_point.get()*/ nullptr, vs->second.get(), ps2->second.get(),
               SR::Buffers::color_out.srv.get(), game_device_data->rtvstate_buffers.rtv.get(), SR::Buffers::color_out.desc.Width, SR::Buffers::color_out.desc.Height);
            
            // restore state
            dss.Restore(native_device_context);
         
            return DrawOrDispatchOverrideType::Replaced;
         }
         
         // case: SR blit to backbuffer
         if (SR::IsOn() && !SR::Buffers::IsNativeResolution() && is_rtv_to_backbuffer_started_this_frame)
         {
            // cache state
            DrawDav::DrawStateStack<DrawDav::DrawStateStackType::SimpleGraphics> dss; //w/o SRV cache, since it crashes game... somehow
            dss.Cache(native_device_context, 0);
         
            // SPECIAL RETURN: SMAA T2x didn't draw, so SR is redundant (e.g. blur pass)
            if (!game_device_data->drawn_smaa)
            {
               if (DEVELOPMENT) ASSERT(ps == hash_blit_blur); //the only expected, but let's see...
         
               // orig
               original_draw_dispatch_func->operator()();
         
               // insert
               DrawCustomPixelShaderPass(native_device, native_device_context,
                  game_device_data->rtvstate_buffers.rtv.get(), device_data,
                  CompileTimeStringHash(NativeShaders::Luma_h1_RenderIntermediatePass_PS), game_device_data->rtvstate_custompassdata);
         
               // restore
               dss.Restore(native_device_context);
               
               return DrawOrDispatchOverrideType::Replaced;
            }
         
            // sr_instance_data
            auto* sr_instance_data = device_data.GetSRInstanceData();
            if (DEVELOPMENT && !sr_instance_data)
            {
               ASSERT_ONCE_MSG(false, "sr_instance_data is null!?!?!");
               return DrawOrDispatchOverrideType::Skip;
            }
            
            // replace color_in with srv4 (hash_blit0, hash_blit_blur)
            {
               ID3D11ShaderResourceView* p1 = nullptr;
               native_device_context->PSGetShaderResources(4, 1, &p1);
               SR::Buffers::color_in.srv.reset(p1);
               if (DEVELOPMENT) ASSERT(SR::Buffers::color_in.srv != nullptr); //impossible
         
               ID3D11Resource* p2 = nullptr;
               SR::Buffers::color_in.srv->GetResource(&p2);
               SR::Buffers::color_in.res.reset(p2);
            }
            
            //TODO: reduce copy paste!
         
            // FAILED: vs not found
            auto vs = device_data.native_vertex_shaders.find(CompileTimeStringHash("Copy VS"));
            if (vs == device_data.native_vertex_shaders.end() || !vs->second.get())
            {
               dss.Restore(native_device_context);
               return DrawOrDispatchOverrideType::Skip;
            }
            
            // FAILED: Luma_h1_SRMotionVectorIn_PS not found
            auto ps0 = device_data.native_pixel_shaders.find(CompileTimeStringHash(NativeShaders::Luma_h1_SRMotionVectorIn_PS));
            if (ps0 == device_data.native_pixel_shaders.end() || !ps0->second.get()) 
            {
               dss.Restore(native_device_context);
               return DrawOrDispatchOverrideType::Skip;
            }
            
            // motion vectors: draw (and its setup)
            DrawCustomPixelShader(native_device_context, nullptr, nullptr, nullptr, vs->second.get(), ps0->second.get(),
               SR::Buffers::motionvectors.srv.get(), SR::Buffers::motionvectors_linear.rtv.get(), SR::Buffers::motionvectors_linear.desc.Width, SR::Buffers::motionvectors_linear.desc.Height);
            
            // FAILED: Luma_h1_SRColorIn_PS not found
            auto ps1 = device_data.native_pixel_shaders.find(CompileTimeStringHash(NativeShaders::Luma_h1_SRColorIn_PS));
            if (ps1 == device_data.native_pixel_shaders.end() || !ps1->second.get()) 
            {
               dss.Restore(native_device_context);
               return DrawOrDispatchOverrideType::Skip;
            }
            
            // color in: draw linearize
            DrawCustomPixelShader(native_device_context, nullptr, nullptr, nullptr, vs->second.get(), ps1->second.get(),
               SR::Buffers::color_in.srv.get(), SR::Buffers::color_in_linear.rtv.get(), SR::Buffers::color_in_linear.desc.Width, SR::Buffers::color_in_linear.desc.Height);
         
            // SR!
            device_data.has_drawn_sr = SR::Draw(device_data, native_device_context, sr_instance_data, SR::Buffers::color_in.GetDimensions(), SR::Buffers::color_out.GetDimensions(),
               SR::Buffers::depth.res.get(), SR::Buffers::motionvectors_linear.res.get(), SR::Buffers::color_in_linear.res.get(), SR::Buffers::color_out.res.get());
         
            // FAILED: SR failed!!!
            if (!device_data.has_drawn_sr)
            {
               ASSERT_ONCE_MSG(false, "SR failed to draw!");
               dss.Restore(native_device_context);
               device_data.force_reset_sr = true;
               return DrawOrDispatchOverrideType::Replaced;
            }
         
            // FAILED: Luma_h1_SRColorOut_PS not found
            auto ps2 = device_data.native_pixel_shaders.find(CompileTimeStringHash(NativeShaders::Luma_h1_SRColorOut_PS));
            if (ps2 == device_data.native_pixel_shaders.end() || !ps2->second.get())
            {
               dss.Restore(native_device_context);
               return DrawOrDispatchOverrideType::Skip;
            }
            
            // color out linearize/copy: draw
            DrawCustomPixelShader(native_device_context, nullptr, nullptr, /*device_data.sampler_state_point.get()*/ nullptr, vs->second.get(), ps2->second.get(),
               SR::Buffers::color_out.srv.get(), game_device_data->rtvstate_buffers.rtv.get(), SR::Buffers::color_out.desc.Width, SR::Buffers::color_out.desc.Height);
            
            // restore state
            dss.Restore(native_device_context);
         
            return DrawOrDispatchOverrideType::Replaced;
         }
         
         // case: even after all of that, we still haven't drawn RenderIntermediatePass, so do it now (e.g. when SR is off)
         if (!device_data.has_drawn_sr && is_rtv_to_backbuffer_started_this_frame)
         {
            // Draw original
            original_draw_dispatch_func->operator()();
            
            // RenderIntermediatePass on rtv / backbuffer
            {
               // Cache
               DrawDav::DrawStateStack<DrawDav::DrawStateStackType::SimpleGraphics> dss; //w/o SRV cache
               dss.Cache(native_device_context, 0);
            
               // Insert/Draw
               DrawCustomPixelShaderPass(native_device, native_device_context,
                  game_device_data->rtvstate_buffers.rtv.get(), device_data,
                  CompileTimeStringHash(NativeShaders::Luma_h1_RenderIntermediatePass_PS), game_device_data->rtvstate_custompassdata);
            
               // Restore
               dss.Restore(native_device_context);
            }

            return DrawOrDispatchOverrideType::Replaced;
         }
         
         return result;
      }
      
      void OnPresent(ID3D11Device* native_device, ID3D11DeviceContext* native_device_context, DeviceData& device_data) override
      {
         GameDeviceDataH2* game_data = static_cast<GameDeviceDataH2*>(device_data.game);
         game_data->OnPresent(native_device, native_device_context, device_data);
      }
   };
   
   static void OnDllMainAfterGameIdentity(GameIdentity::GameType game)
   {
      switch (game)
      {
         case GameIdentity::GameType::H1: cod = std::make_unique<H1>(); break;
         case GameIdentity::GameType::H2: cod = std::make_unique<H2>(); break;
         default: ASSERT_MSG(false, "(CODs::OnDllMainAfterGameIdentity()) FATAL ERROR, Unknown game!"); break;
      }
      cod->OnDllMain();
   }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

namespace CB
{
   static void OnInit()
   {
      default_luma_global_game_settings.FMVPaperWhite = cb_luma_global_settings.GameSettings.FMVPaperWhite = default_paper_white;
      default_luma_global_game_settings.ExposurePost = cb_luma_global_settings.GameSettings.ExposurePost = 1;
      default_luma_global_game_settings.ExposurePre = cb_luma_global_settings.GameSettings.ExposurePre = 1;
      // default_luma_global_game_settings.RenderResolutionScale = cb_luma_global_settings.GameSettings.RenderResolutionScale = -1;
      default_luma_global_game_settings.Bloom = cb_luma_global_settings.GameSettings.Bloom = 1;
      default_luma_global_game_settings.AllowVanillaColorGrade = cb_luma_global_settings.GameSettings.AllowVanillaColorGrade = 1; //dont save!
      default_luma_global_game_settings.AllowFullscreenBlur = cb_luma_global_settings.GameSettings.AllowFullscreenBlur = 1; //dont save!
      default_luma_global_game_settings.PCCChrom = cb_luma_global_settings.GameSettings.PCCChrom = 1.f; //TODO use or nah?
      default_luma_global_game_settings.PCCHue = cb_luma_global_settings.GameSettings.PCCHue = 1.f; //TODO use or nah?
      default_luma_global_game_settings.PCCPeak = cb_luma_global_settings.GameSettings.PCCPeak = 1.f;
   }
   
   static void OnLoadConfigs(reshade::api::effect_runtime* runtime)
   {
      reshade::get_config_value(runtime, NAME, "FMVPaperWhite", cb_luma_global_settings.GameSettings.FMVPaperWhite);
      reshade::get_config_value(runtime, NAME, "ExposurePost", cb_luma_global_settings.GameSettings.ExposurePost);
      reshade::get_config_value(runtime, NAME, "ExposurePre", cb_luma_global_settings.GameSettings.ExposurePre);
      reshade::get_config_value(runtime, NAME, "Bloom", cb_luma_global_settings.GameSettings.Bloom);
      reshade::get_config_value(runtime, NAME, "PCCChrom", cb_luma_global_settings.GameSettings.PCCChrom);
      reshade::get_config_value(runtime, NAME, "PCCHue", cb_luma_global_settings.GameSettings.PCCHue);
      reshade::get_config_value(runtime, NAME, "PCCPeak", cb_luma_global_settings.GameSettings.PCCPeak);
      
      // custom_sdr_gamma
      reshade::get_config_value(runtime, NAME, "custom_sdr_gamma", custom_sdr_gamma);
      ShaderDefineInfo::Set(GAMMA_CORRECTION_TYPE_HASH, custom_sdr_gamma > 0);
      defines_need_recompilation = true;
   }

   // Saving is handled by ImGui on user changes, see SectionedImGui.
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class CallOfDutyDX11 final : public Game
{
public:
   void OnInit(bool async) override
   {
      message(reshade::log::level::info, "OnInit()");

      luma_settings_cbuffer_index = 13; //TODO: IW must dodge 13
      luma_data_cbuffer_index = 12;

      // cbuffers
      CB::OnInit();
      CODs::cod->OnInitCBOverride();

      // Defines
      shader_defines_data.append_range(ShaderDefineInfo::game_shader_defines_data);
      ASSERT(shader_defines_data.size() < MAX_SHADER_DEFINES);
      auto_recompile_defines = true; //force

      // Default built-in
      GetShaderDefineData(POST_PROCESS_SPACE_TYPE_HASH).SetDefaultValue('0');
      GetShaderDefineData(EARLY_DISPLAY_ENCODING_HASH).SetDefaultValue('0');
      GetShaderDefineData(VANILLA_ENCODING_TYPE_HASH).SetDefaultValue('0');
      GetShaderDefineData(GAMMA_CORRECTION_TYPE_HASH).SetDefaultValue('1');
      GetShaderDefineData(UI_DRAW_TYPE_HASH).SetDefaultValue('2');
      if (!DEVELOPMENT)
      {
         GetShaderDefineData(TEST_SDR_HDR_SPLIT_VIEW_MODE_NATIVE_IMPL_HASH).SetValueFixed(true);
         GetShaderDefineData(TEST_SDR_HDR_SPLIT_VIEW_MODE_NATIVE_IMPL_HASH)   .editable = false;
         GetShaderDefineData(char_ptr_crc32("TEST_SDR_HDR_SPLIT_VIEW_MODE")).SetValueFixed(true);
         GetShaderDefineData(char_ptr_crc32("TEST_SDR_HDR_SPLIT_VIEW_MODE")).editable = false;
      }

      // Native Shaders
      NativeShaders::OnInit();
   }

   void OnCreateDevice(ID3D11Device* native_device, DeviceData& device_data) override
   {
      message(reshade::log::level::info, "OnCreateDevice()");

      CODs::cod->OnCreateDevice(native_device, device_data);
   }

   void OnInitSwapchain(reshade::api::swapchain* swapchain) override
   {
      message(reshade::log::level::info, "OnInitSwapchain()");
      // auto& device_data = *swapchain->get_device()->get_private_data<DeviceData>();
   }

   DrawOrDispatchOverrideType OnDrawOrDispatch(ID3D11Device* native_device, ID3D11DeviceContext* native_device_context, CommandListData& cmd_list_data, DeviceData& device_data, reshade::api::shader_stage stages, const ShaderHashesList<OneShaderPerPipeline>&  original_shader_hashes, bool is_custom_pass, bool& updated_cbuffers, std::function<void()>* original_draw_dispatch_func) override
   {
      if (Globals::pipeline_is_skipondrawordispatch) return DrawOrDispatchOverrideType::None;
      return CODs::cod->OnDrawOrDispatch(native_device, native_device_context, cmd_list_data, device_data, stages, original_shader_hashes, is_custom_pass, updated_cbuffers, original_draw_dispatch_func);
   }

   void OnPresent(ID3D11Device* native_device, DeviceData& device_data) override
   {
      SR::OnPreset(native_device, device_data);
      SR::Jitter::OnPresent(native_device, device_data);
      CODs::cod->OnPresent(native_device, nullptr, device_data);
   }

   void CleanExtraSRResources(DeviceData& device_data) override
   {
      SR::Buffers::HardReset();
   }

   void LoadConfigs() override
   {
      message(reshade::log::level::info, "LoadConfigs()");
      reshade::api::effect_runtime* runtime = nullptr;

      CB::OnLoadConfigs(runtime);
      SR::Jitter::OnLoad(runtime);
      SectionedImGui::OnLoadConfigs(runtime);
   }

   void DrawImGuiSettings(DeviceData& device_data) override
   {
      reshade::api::effect_runtime* runtime = nullptr;

      // Below Luma's brightness settings
      ImGui::Separator();

      // DRAW
      SectionedImGui::OnDraw(runtime, device_data);

      // Debug stuff
      if (DEVELOPMENT)
      {
         
      }

      // For rest of Luma's default
      if (DEVELOPMENT) ImGui::Separator();
   }

   void PrintImGuiAbout() override
   {
      ImGui::Text("Build Date:");
      ImGui::Text(__DATE__);
      ImGui::Text(__TIME__);
      ImGui::NewLine();

      ImGui::Text("Additional Credits:");
      ImGui::BulletText("Luma: Pumbo (Filoppi)");
      ImGui::BulletText("RenoDX: clshortfuse");

      ImGui::NewLine();
      ImGui::Text("Third Party:");
      ImGui::BulletText("ReShade");
      ImGui::BulletText("ImGui");
      ImGui::BulletText("RenoDX");
      ImGui::BulletText("3Dmigoto");
      ImGui::BulletText("Oklab");
      ImGui::BulletText("JzAzBz");
      ImGui::BulletText("Dolby");
      ImGui::BulletText("NVIDIA");
      ImGui::BulletText("AMD");
      ImGui::BulletText("DICE");
   }
};

BOOL APIENTRY DllMain(HMODULE hModule, DWORD ul_reason_for_call, LPVOID lpReserved)
{
   if (ul_reason_for_call == DLL_PROCESS_ATTACH)
   {
      Globals::SetGlobals(PROJECT_NAME, "Call of Duty DX11");

      swapchain_format_upgrade_type  = TextureFormatUpgradesType::AllowedEnabled;
      swapchain_upgrade_type         = SwapchainUpgradeType::scRGB;

      enable_samplers_upgrade        = true; //SR
      
      prevent_fullscreen_state       = false; //must, game explodes trying to create initial swapchain
      force_ignore_dpi               = true;
      
      GameIdentity::OnDllMain();
      CODs::OnDllMainAfterGameIdentity(GameIdentity::game);
      SectionedImGui::OnDllMainAfterGameIdentity(GameIdentity::game);

      game = new CallOfDutyDX11();
   }

   CoreMain(hModule, ul_reason_for_call, lpReserved);

   return TRUE;
}