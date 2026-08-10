#define GAME_HALOTMCC 1

// #define ENABLE_AUTO_CBUFFER_RESTORATION 1 //When off, conflicts H2A, but not detrimental
#define DISABLE_AUTO_DEBUGGER 1
#include "..\..\Core\core.hpp"

#define HALO_UPGRADE_SAMPLERS 0 // On is volatile for H2C

// ImGui util to edit Shader Defines
namespace ShaderDefines
{
   constexpr uint32_t ALLOW_AA = char_ptr_crc32("ALLOW_AA");
   constexpr uint32_t ALLOW_COLORGRADE = char_ptr_crc32("ALLOW_COLORGRADE");
   constexpr uint32_t HALO3_BLOOM = char_ptr_crc32("HALO3_BLOOM");
   constexpr uint32_t SWAPCHAIN_TEST_PEAK = char_ptr_crc32("SWAPCHAIN_TEST_PEAK");

   void OnInitAddNewDefines()
   {
      std::vector<ShaderDefineData> game_shader_defines_data = {
         {"GAMMA_CORRECTION_RANGE_TYPE", '0', true, !DEVELOPMENT, "0 - Full range.\n1 - 0-1 only.", 1},
         {"ALLOW_AA", '1', true, false, "Allow original anti-alias.", 1},
         {"ALLOW_COLORGRADE", '1', true, false, "Allow original color grading.", 1},
         {"HALO3_BLOOM", '1', true, false, "Halo 3 bloom mode.", 1},
         {"SWAPCHAIN_TEST_PEAK", '0', true, false, "Test pattern", 1},
      };
      shader_defines_data.append_range(game_shader_defines_data);
      assert(shader_defines_data.size() < MAX_SHADER_DEFINES);
   }
   
   static char InvertCharBool(char b)
   {
      return b == '0' ? '1' : '0'; 
   }
   
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

      if (tooltip && ImGui::IsItemHovered(ImGuiHoveredFlags_AllowWhenDisabled)) ImGui::SetTooltip(tooltip);
      
      if (c) ToggleBool(d);
      
      UIResetButton(d);
      return def;
   }
      
   static int UIDropDown(uint32_t d, const char* label, const char* const items[], const char* tooltip)
   {
      int def = Get(d);
      bool c = ImGui::Combo(label, &def, items, IM_ARRAYSIZE(items));
      if (c) Set(d, def);
      if (tooltip && ImGui::IsItemHovered(ImGuiHoveredFlags_AllowWhenDisabled)) ImGui::SetTooltip(tooltip);
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

namespace 
{
   // Buffer
   struct Buffer
   {
      D3D11_TEXTURE2D_DESC desc;
      ComPtr<ID3D11Texture2D> tex;
      ComPtr<ID3D11Resource> res;
      ComPtr<ID3D11ShaderResourceView> srv;
      ComPtr<ID3D11RenderTargetView> rtv;
      ComPtr<ID3D11UnorderedAccessView> uav;

      uint2 GetDimensions() const
      {
         return { desc.Width, desc.Height };
      }
      
      void Reset()
      {
         desc = {};
         res.reset();
         tex.reset();
         srv.reset();
         rtv.reset();
         uav.reset();
      }

      void CreateWithCurrentDesc(ID3D11Device* device)
      {
         auto hr0 = device->CreateTexture2D(&desc, nullptr, tex.put());
         if (DEVELOPMENT) ASSERT_ONCE(SUCCEEDED(hr0));

         auto hr1 = tex->QueryInterface(res.put());
         if (DEVELOPMENT) ASSERT_ONCE(SUCCEEDED(hr1));

         auto hr2 = device->CreateRenderTargetView(tex.get(), nullptr, rtv.put());
         if (DEVELOPMENT) ASSERT_ONCE(SUCCEEDED(hr2));
      
         auto hr3 = device->CreateShaderResourceView(tex.get(), nullptr, srv.put());
         if (DEVELOPMENT) ASSERT_ONCE(SUCCEEDED(hr3));
      }

      static D3D11_TEXTURE2D_DESC GetDefaultDesc(uint2 output_resolution, DXGI_FORMAT format = DXGI_FORMAT_R16G16B16A16_FLOAT)
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
   
   ///////////////////////////////////
   
   // SubGame
   enum SubGame : uint8_t
   {
      Unknown,
      Halo1Classic,
      Halo1Anniversary,
      Halo2Classic,
      Halo2Anniversary,
      Halo2AnniversaryMP,
      Halo3,
      Halo3ODST,
      HaloReach,
      Halo4,
   };
   const char* SubGameToString(SubGame state, bool is_space = true)
   {
      switch (state)
      {
      case Unknown: return "Unknown";
      case Halo1Classic: return is_space ? "Halo 1 Classic" : "Halo1Classic";
      case Halo1Anniversary: return is_space ? "Halo 1 Anniversary" : "Halo1Anniversary";
      case Halo2Classic: return is_space ? "Halo 2 Classic" : "Halo2Classic";
      case Halo2Anniversary: return is_space ? "Halo 2 Anniversary" : "Halo2Anniversary";
      case Halo2AnniversaryMP: return is_space ? "Halo 2 Anniversary Multiplayer" : "Halo2AnniversaryMP";
      case Halo3: return is_space ? "Halo 3" : "Halo3";
      case Halo3ODST: return is_space ? "Halo 3 ODST" : "Halo3ODST";
      case HaloReach: return is_space ? "Halo Reach" : "HaloReach";
      case Halo4: return is_space ? "Halo 4" : "Halo4";
      default: return "Unknown";
      }
   }
   
   ///////////////////////////////////

   // Clear Indirect Upgrades Handler
   namespace ClearIndirectUpgradesHandler
   {
      bool is_queued = false;
      void Request()
      {
         is_queued = true;
      }
      void OnReShadePresent(reshade::api::effect_runtime* runtime)
      {
         // return when not queued
         if (!is_queued) return;
         is_queued = false;

         // log
         reshade::log::message(reshade::log::level::info, "Clearing indirect upgrades");

         // clear old upgrades
         DeviceData& device_data = *runtime->get_device()->get_private_data<DeviceData>();
         std::unordered_map<uint64_t, uint64_t> original_resource_views_to_mirrored_upgraded_resource_views;
         std::unordered_map<uint64_t, uint64_t> original_resources_to_mirrored_upgraded_resources;
         std::shared_lock lock_device_read(device_data.mutex);
         
         if (!device_data.original_resources_to_mirrored_upgraded_resources.empty())
         {
            lock_device_read.unlock();
            {
               std::unique_lock lock_device_write(device_data.mutex);
               original_resource_views_to_mirrored_upgraded_resource_views = device_data.original_resource_views_to_mirrored_upgraded_resource_views;
               original_resources_to_mirrored_upgraded_resources = device_data.original_resources_to_mirrored_upgraded_resources;
               device_data.original_resource_views_to_mirrored_upgraded_resource_views.clear();
               device_data.original_resources_to_mirrored_upgraded_resources.clear();
            }
            for (const auto& original_resource_view_to_mirrored_upgraded_resource_view : original_resource_views_to_mirrored_upgraded_resource_views)
               runtime->get_device()->destroy_resource_view({ original_resource_view_to_mirrored_upgraded_resource_view.second });
            for (const auto& original_resource_to_mirrored_upgraded_resource : original_resources_to_mirrored_upgraded_resources)
               runtime->get_device()->destroy_resource({ original_resource_to_mirrored_upgraded_resource.second });
         }
      }
   }
   
   ///////////////////////////////////
   
   namespace WarmupDirectAndIndirectHandler
   {
      // Optimization to avoid heavy indirect upgrades scanning
      int warmup_frames = 0;
      ChainTextureFormatUpgradesType warmup_end = ChainTextureFormatUpgradesType::DirectDependencies;
      void Start(int frames = 4, ChainTextureFormatUpgradesType type = ChainTextureFormatUpgradesType::DirectAndIndirectDependencies, ChainTextureFormatUpgradesType end_type = ChainTextureFormatUpgradesType::DirectDependencies)
      {
         warmup_frames = frames;
         enable_chain_indirect_texture_format_upgrades = type;
         warmup_end = end_type;
      }
      void OnPresent()
      {
         if (warmup_frames > -1) warmup_frames--;
         if (warmup_frames == 0) enable_chain_indirect_texture_format_upgrades =
            (ChainTextureFormatUpgradesType)(max((uint8_t)ChainTextureFormatUpgradesType::None, (uint8_t)ChainTextureFormatUpgradesType::DirectDependencies - 1));
      }
   }
   
   ///////////////////////////////////

   namespace SubGameUserSettingsHandler
   {
      bool enabled = false;
      
      struct Settings
      {
         SubGame subgame;
         int peak;
         int paper_scene;
         int paper_ui;

         enum Compatibilty : uint8_t
         {
            NotSupported,
            WIP,
            Untested,
            Working,
         };
         Compatibilty compatibility;

         std::pair<const char*, ImVec4> GetCompatibility() const
         {
            switch (compatibility)
            {
               case NotSupported: return std::make_tuple("Not Supported", ImColor(255, 0, 0)); // Red
               case WIP: return std::make_tuple("WIP", ImColor(255, 165, 0)); // Orange
               case Untested: return std::make_tuple("Untested", ImColor(255, 255, 0)); // Yellow
               case Working: return std::make_tuple("Working", ImColor(0, 255, 0)); // Green
               default: return std::make_tuple("Unknown", ImColor(0, 0, 0));
            }
         }

         // Default constructor taking in name and compatibility
         Settings(SubGame subgame, Compatibilty compatibility)
            : subgame(subgame), peak(0), paper_scene(0), paper_ui(0), compatibility(compatibility) {}
      };

      std::vector<Settings> settings = {
         { Unknown, Settings::Working },
         { Halo1Classic, Settings::Working },
         { Halo1Anniversary, Settings::WIP },
         { Halo2Classic, Settings::WIP },
         { Halo2Anniversary,  Settings::Working },
         { Halo2AnniversaryMP, Settings::NotSupported },
         { Halo3,  Settings::Untested },
         { Halo3ODST, Settings::Untested },
         { HaloReach, Settings::Untested },
         { Halo4, Settings::Untested },
      };

      Settings* GetSettings(SubGame subgame)
      {
         auto s = &settings[subgame];
         ASSERT_MSG(s, "Settings for SubGame not found");
         return s;
      }

      void OnSubGameChange(SubGame new_game)
      {
         if (!enabled) return;

         auto sg = GetSettings(new_game);
         if (!sg) return;

         reshade::log::message(reshade::log::level::info, std::format("SubGameUserSettingsHandler Applying SubGame settings for {}: Peak={}, ScenePaperWhite={}, GamePaperWhite={}", SubGameToString(new_game), sg->peak, sg->paper_scene, sg->paper_ui).c_str());

         if (sg->peak > 0) cb_luma_global_settings.ScenePeakWhite = sg->peak;
         if (sg->paper_scene > 0) cb_luma_global_settings.ScenePaperWhite = sg->paper_scene;
         if (sg->paper_ui > 0) cb_luma_global_settings.UIPaperWhite = sg->paper_ui;
      }

      const char* GetSubGameSaveKey(SubGame state, const char* setting_name)
      {
         return std::format("{}_{}", SubGameToString(state, false), setting_name).c_str();
      }

      constexpr const char* reshade_config_section = "SubGameUserSettingsHandler";
      void OnImGui()
      {
         if (ImGui::Checkbox("Enable Per Game Settings", &enabled))
            reshade::set_config_value(nullptr, reshade_config_section, "EnablePerGameSettings", enabled);

         if (!enabled) ImGui::BeginDisabled();
         for (const auto& sg : settings)
         {
            ImGui::PushID(("###SubGameUserSettingsHandler" + std::to_string(sg.subgame)).c_str());
            if (ImGui::TreeNode(SubGameToString(sg.subgame)))
            {
               auto [compatibility_text, compatibility_color] = sg.GetCompatibility();
               ImGui::PushStyleColor(ImGuiCol_Text, compatibility_color);
               ImGui::TextWrapped("Compatibility: %s", compatibility_text);
               ImGui::PopStyleColor();
               
               auto* s = GetSettings(sg.subgame);

               int peak = s->peak;
               int paper_scene = s->paper_scene;
               int paper_ui = s->paper_ui;

               /*ImGui::SameLine();*/ if (ImGui::Button("Set: Luma Defaults")) { s->peak = default_peak_white; s->paper_scene = default_paper_white; s->paper_ui = default_paper_white; }
               ImGui::SameLine(); if (ImGui::Button("Set: Current Settings")) { s->peak = cb_luma_global_settings.ScenePeakWhite; s->paper_scene = cb_luma_global_settings.ScenePaperWhite; s->paper_ui = cb_luma_global_settings.UIPaperWhite; }
               ImGui::SameLine(); if (ImGui::Button("Set: Disable")) { s->peak = 0; s->paper_scene = 0; s->paper_ui = 0; }

               auto GetFormat = [](int v) { return v > 0 ? "%d" : "%d (Inactive)"; };
               ImGui::SliderInt("Display Peak", &s->peak, 0, 4000, GetFormat(s->peak));
               if (s->subgame != Unknown) ImGui::SliderInt("Scene Paper White", &s->paper_scene, 0, 400, GetFormat(s->paper_scene));
               ImGui::SliderInt("UI Paper White", &s->paper_ui, 0, 400, GetFormat(s->paper_ui));
               
               if (peak != s->peak) reshade::set_config_value(nullptr, reshade_config_section, GetSubGameSaveKey(sg.subgame, "Peak"), s->peak);
               if (paper_scene != s->paper_scene) reshade::set_config_value(nullptr, reshade_config_section, GetSubGameSaveKey(sg.subgame, "Scene"), s->paper_scene);
               if (paper_ui != s->paper_ui) reshade::set_config_value(nullptr, reshade_config_section, GetSubGameSaveKey(sg.subgame, "UI"), s->paper_ui);

               ImGui::TreePop();
            }
            ImGui::PopID();
         }
         if (!enabled) ImGui::EndDisabled();
      }

      void OnLoadConfigs()
      {
         reshade::get_config_value(nullptr, reshade_config_section, "EnablePerGameSettings", enabled);

         for (auto& sg : settings)
         {
            auto* s = GetSettings(sg.subgame);
            reshade::get_config_value(nullptr, reshade_config_section, GetSubGameSaveKey(sg.subgame, "Peak"), s->peak);
            reshade::get_config_value(nullptr, reshade_config_section, GetSubGameSaveKey(sg.subgame, "Scene"), s->paper_scene);
            reshade::get_config_value(nullptr, reshade_config_section, GetSubGameSaveKey(sg.subgame, "UI"), s->paper_ui);
         }
      }
   }
   
   ///////////////////////////////////

   // SubGame Handler
   namespace SubGameHandler
   {
      // SubGame state
      SubGame curr = Unknown;
      SubGame over = Unknown;
      bool best_resource_unorm_disallow = false;
      void SetSubGame(SubGame new_game)
      {
         // return when clean up is queued
         if (ClearIndirectUpgradesHandler::is_queued) return;
         
         // resolve override
         if (over != Unknown) new_game = over;
         
         // prev
         auto prev_game = curr;
         bool is_changed = prev_game != new_game;

         // last
         static auto last_game = Unknown; //last known successful
         bool is_completely_changed = false;
         if (new_game != Unknown)
         {
            is_completely_changed = last_game != new_game;
            last_game = new_game;
         }

         // completely changed, so clear indirect upgrades
         if (is_completely_changed)
         {
            ClearIndirectUpgradesHandler::Request();
            curr = Unknown;
            return;
         }

         // set
         curr = new_game;
         cb_luma_global_settings.GameSettings.SubGame = static_cast<int>(curr);

         // not changed, so useless to continue ////////////////////////////////////////////////////////
         if (!is_changed) return; 
         
         // log
         reshade::log::message(reshade::log::level::info, std::format("SubGame changed from {} to {}", SubGameToString(prev_game), SubGameToString(curr)).c_str());
            
         // SubGameUserSettingsHandler
         SubGameUserSettingsHandler::OnSubGameChange(curr);
            
         // reset upgrades params
         enable_chain_indirect_texture_format_upgrades = ChainTextureFormatUpgradesType::DirectDependencies;
         best_resource_unorm = false; //TODO: Luma needs this or something better for core.hpp!
         ignore_upgraded_samplers = true;
            
         // clear old hashes
         auto_texture_format_upgrade_shader_hashes.clear();
            
         // set new Indirect Upgrades hashes
         auto_texture_format_upgrade_shader_hashes[0x5B190892] = std::pair{ std::vector<uint8_t>{ 0 }, std::vector<uint8_t>() }; //ui blurdown00
         switch (curr)
         {
            case Halo1Classic:
               auto_texture_format_upgrade_shader_hashes[0xB70CC18B] = std::pair{ std::vector<uint8_t>{ 0 }, std::vector<uint8_t>() }; //fxaa
               if (!best_resource_unorm_disallow) best_resource_unorm = true; //TODO: Luma needs this or something better for core.hpp!
               break;
            case Halo1Anniversary:
               // auto_texture_format_upgrade_shader_hashes[0xDCC32775] = std::pair{ std::vector<uint8_t>{ 0 }, std::vector<uint8_t>() }; //transparency combine
               // auto_texture_format_upgrade_shader_hashes[0x700325CF] = std::pair{ std::vector<uint8_t>{ 0 }, std::vector<uint8_t>() }; //downsample (exposure)
               // auto_texture_format_upgrade_shader_hashes[0xB70CC18B] = std::pair{ std::vector<uint8_t>{ 0 }, std::vector<uint8_t>() }; //fxaa
               best_resource_unorm = true;
               break;
            case Halo2Classic:
               auto_texture_format_upgrade_shader_hashes[0xD39821CB] = std::pair{ std::vector<uint8_t>{ 0 }, std::vector<uint8_t>() }; //blit
               if (!best_resource_unorm_disallow) best_resource_unorm = true; //TODO: Luma needs this or something better for core.hpp!
               break;
            case Halo2Anniversary:
               // 0x65E212E2 normals downsample (orig: SRV0)
               auto_texture_format_upgrade_shader_hashes[0x8D11B112] = std::pair{ std::vector<uint8_t>{ 0 }, std::vector<uint8_t>() }; //t00
               auto_texture_format_upgrade_shader_hashes[0xBDDD9A3C] = std::pair{ std::vector<uint8_t>{ 0 }, std::vector<uint8_t>() }; //t01
               auto_texture_format_upgrade_shader_hashes[0xE5A32080] = std::pair{ std::vector<uint8_t>{ 0 }, std::vector<uint8_t>() }; //t02
               auto_texture_format_upgrade_shader_hashes[0xB5D334B0] = std::pair{ std::vector<uint8_t>{ 0 }, std::vector<uint8_t>() }; //aa
               auto_texture_format_upgrade_shader_hashes[0x9EC6DFC8] = std::pair{ std::vector<uint8_t>{ 0 }, std::vector<uint8_t>() }; //blit
               auto_texture_format_upgrade_shader_hashes[0xBF5A726E] = std::pair{ std::vector<uint8_t>{ 0 }, std::vector<uint8_t>() }; //after blit downsample blur (concussion)
               auto_texture_format_upgrade_shader_hashes[0x3D30DAB7] = std::pair{ std::vector<uint8_t>{ 0 }, std::vector<uint8_t>() }; //some generic copy that runs after CopyResource()
               ignore_upgraded_samplers = false;
               break;
            case Halo3:
               auto_texture_format_upgrade_shader_hashes[0xEEB815BC] = std::pair{ std::vector<uint8_t>{ 0 }, std::vector<uint8_t>() }; //t00 //TODO: more variants?
               auto_texture_format_upgrade_shader_hashes[0x9EC6DFC8] = std::pair{ std::vector<uint8_t>{ 0 }, std::vector<uint8_t>() }; //fxaa
               WarmupDirectAndIndirectHandler::Start();
               break;
            case Halo3ODST:
               auto_texture_format_upgrade_shader_hashes[0xADADBE3D] = std::pair{ std::vector<uint8_t>{ 0 }, std::vector<uint8_t>() }; //t00 //TODO: more variants?
               auto_texture_format_upgrade_shader_hashes[0x9EC6DFC8] = std::pair{ std::vector<uint8_t>{ 0 }, std::vector<uint8_t>() }; //fxaa
               auto_texture_format_upgrade_shader_hashes[0x03B68268] = std::pair{ std::vector<uint8_t>{ 0 }, std::vector<uint8_t>() }; //noise overlay
               WarmupDirectAndIndirectHandler::Start();
               break;
            case HaloReach:
               auto_texture_format_upgrade_shader_hashes[0xC1FF277A] = std::pair{ std::vector<uint8_t>{ 0 }, std::vector<uint8_t>() }; //t00
               auto_texture_format_upgrade_shader_hashes[0x0EFB2B17] = std::pair{ std::vector<uint8_t>{ 0 }, std::vector<uint8_t>() }; //fxaa
               break;
            case Halo4:
               auto_texture_format_upgrade_shader_hashes[0x3A2F6CF7] = std::pair{ std::vector<uint8_t>{ 0 }, std::vector<uint8_t>() }; //t00
               auto_texture_format_upgrade_shader_hashes[0xB38416A2] = std::pair{ std::vector<uint8_t>{ 0 }, std::vector<uint8_t>() }; //t01
               auto_texture_format_upgrade_shader_hashes[0xCCC24837] = std::pair{ std::vector<uint8_t>{ 0 }, std::vector<uint8_t>() }; //fxaa
               break;
            default: ;
         }
      }
      
      // Safer way to switch in OnDrawOrDispatch()
      SubGame queued = Unknown;
      void Enqueue(SubGame game, bool is_override = false)
      {
         if (!is_override && queued != Unknown) return;
         queued = game;
      }
      // Dequeued on OnPresent()
      void Deque(DeviceData& device_data)
      {
         SetSubGame(queued);
         queued = Unknown;
      }

      // full reset!
      void Reinit()
      {
         queued = Unknown;
         over = Unknown;
         SetSubGame(Unknown);
      }
   };
   
   ///////////////////////////////////////////////

#if HALO_UPGRADE_SAMPLERS
   // mip_lod_bias_offset
   float mip_lod_bias_offset = 0.f; //allow user to set offset //TODO: works, but CAUSES CRASH FOR H2C!!!
   void SetMipLodBiasOffset(float offset, bool save_to_config = true)
   {
      mip_lod_bias_offset = offset;
      if (save_to_config) reshade::set_config_value(nullptr, NAME, "mip_lod_bias_offset", mip_lod_bias_offset);
   }
#endif
   
   ///////////////////////////////////////////////

   // allow_gamma_slider
   bool allow_gamma_slider = false;
   constexpr uint32_t gamma_slider_hash = 0x82BED845;
   bool GammaSliderIsHash(uint64_t ps) { return ps == gamma_slider_hash; }
   bool GammaSliderIsAllowDraw(uint64_t ps) { return ps != gamma_slider_hash || allow_gamma_slider; }
   
   ///////////////////////////////////////////////

   // GetPulsingColor
   ImVec4 GetPulsingColor(ImColor color, float speed = 0.1f, float amount = 0.25f)
   {
      float m = (1.f-amount/2) + amount/2 * sinf(cb_luma_global_settings.FrameIndex * speed);
      color.Value.x *= m;
      color.Value.y *= m;
      color.Value.z *= m;
      return color;
   }

   ///////////////////////////////////////////////

   constexpr std::string_view Luma_sRGBEncode_PS = "Luma_sRGBEncode_PS";
   constexpr std::string_view Luma_DisplayComposition1 = "Luma_DisplayComposition1";
}

// struct GameDeviceDataHaloTMCC : GameDeviceData
// {   
//
// };

class GameHaloTMCC final : public Game
{   
public:
   void OnInit(bool async) override
   {
      // cb
      luma_settings_cbuffer_index = 9;  //though conflict, no problem
      luma_data_cbuffer_index     = 10; //though conflict, no problem

      // cb init
      default_luma_global_game_settings.Bloom = cb_luma_global_settings.GameSettings.Bloom = 1.f;
      default_luma_global_game_settings.FilmGrain = cb_luma_global_settings.GameSettings.FilmGrain = 1.f;
      default_luma_global_game_settings.WhiteClip = cb_luma_global_settings.GameSettings.WhiteClip = 1.f;

      // Shader Defines
      ShaderDefines::OnInitAddNewDefines();
      GetShaderDefineData(UI_DRAW_TYPE_HASH).SetDefaultValue('3');
      auto_recompile_defines = true;

      // Native Shaders: Display Composition replacement
      native_shaders_definitions.erase(CompileTimeStringHash("Display Composition"));
      native_shaders_definitions.emplace(CompileTimeStringHash("Display Composition"), ShaderDefinition{Luma_DisplayComposition1.data(), reshade::api::pipeline_subobject_type::pixel_shader});

      // OnReShadePresent
      reshade::register_event<reshade::addon_event::reshade_present>(ClearIndirectUpgradesHandler::OnReShadePresent);
   }

   DrawOrDispatchOverrideType OnDrawOrDispatch(ID3D11Device* native_device, ID3D11DeviceContext* native_device_context, CommandListData& cmd_list_data, DeviceData& device_data, reshade::api::shader_stage stages, const ShaderHashesList<OneShaderPerPipeline>& original_shader_hashes, bool is_custom_pass, bool& updated_cbuffers, std::function<void()>* original_draw_dispatch_func) override
   {
      // Setup
      // GameDeviceDataHaloTMCC* game_device_data = static_cast<GameDeviceDataHaloTMCC*>(device_data.game);
      const uint64_t vs = original_shader_hashes.vertex_shaders[0];
      const uint64_t ps = original_shader_hashes.pixel_shaders[0];
      const uint64_t cs = original_shader_hashes.compute_shaders[0];

      // DEVELOPMENT mod active
      if (!custom_shaders_enabled && ignore_indirect_upgraded_textures)
      {
         SubGameHandler::SetSubGame(SubGame::Unknown);
         return DrawOrDispatchOverrideType::None;
      }
      
      ////////////////////////////////////////////////////////////
      
      // Halo1Anniversary: transparency combine
      if (ps == 0xDCC32775)
      {
         SubGameHandler::Enqueue(Halo1Anniversary, true);
         return DrawOrDispatchOverrideType::None;
      }

      // Halo1Classic: fxaa
      if (!device_data.has_drawn_main_post_processing && ps == 0xB70CC18B)
      {
         device_data.has_drawn_main_post_processing = true;
         SubGameHandler::Enqueue(Halo1Classic);
         return DrawOrDispatchOverrideType::None;
      }
      
      // Halo2Anniversary: AO
      // TODO: XeGTAO by stealing non-downsampled depth and normals
      
      // Halo2Anniversary: blit
      if (!device_data.has_drawn_main_post_processing && ps == 0x9275F36F)
      {
         device_data.has_drawn_main_post_processing = true;
         SubGameHandler::Enqueue(Halo2Anniversary);
         return DrawOrDispatchOverrideType::None;
      }

      // Halo2Classic: blit
      if (!device_data.has_drawn_main_post_processing && ps == 0xD39821CB)
      {
         device_data.has_drawn_main_post_processing = true;
         SubGameHandler::Enqueue(Halo2Classic);
         return DrawOrDispatchOverrideType::None;
      }

      // Halo3
      constexpr std::array<uint64_t, 1> halo3_ps_hashes = { 0xEEB815BC }; //TODO: more variants?
      if (std::ranges::contains(halo3_ps_hashes, ps))
      {
         SubGameHandler::Enqueue(Halo3);
         return DrawOrDispatchOverrideType::None;
      }
      // Halo3ODST
      constexpr std::array<uint64_t, 2> halo3odst_ps_hashes = { 0xADADBE3D, 0x03B68268 }; //TODO: more variants?
      if (std::ranges::contains(halo3odst_ps_hashes, ps))
      {
         SubGameHandler::Enqueue(Halo3ODST);
         return DrawOrDispatchOverrideType::None;
      }
      // Halo3/ODST: fxaa
      if (!device_data.has_drawn_main_post_processing && ps == 0x9EC6DFC8)
      {
         device_data.has_drawn_main_post_processing = true;
         return DrawOrDispatchOverrideType::None;
      }

      // HaloReach: fxaa
      if (!device_data.has_drawn_main_post_processing && ps == 0x0EFB2B17)
      {
         device_data.has_drawn_main_post_processing = true;
         SubGameHandler::Enqueue(HaloReach);
         return DrawOrDispatchOverrideType::None;
      }

      ////////////////////////////////////////////////////////////

      //ui_blurdown00
      if (ps == 0x5B190892) 
      {
         if (cb_luma_global_settings.GameSettings.UIBlurDown0Count < 2) // not useful > 2.
         {
            cb_luma_global_settings.GameSettings.UIBlurDown0Count++;
            device_data.cb_luma_global_settings_dirty = true;
         }
         return DrawOrDispatchOverrideType::None;
      }

      // In-game Gamma Slider
      if (!GammaSliderIsAllowDraw(ps))
      {
         return DrawOrDispatchOverrideType::Skip;
      }

      return DrawOrDispatchOverrideType::None;
   }

   void OnPresent(ID3D11Device* native_device, DeviceData& device_data) override
   {
      // GameDeviceDataHaloTMCC* game_device_data = static_cast<GameDeviceDataHaloTMCC*>(device_data.game);

#if HALO_UPGRADE_SAMPLERS
      // mip_lod_bias_offset
      device_data.texture_mip_lod_bias_offset = mip_lod_bias_offset;
#endif

      // SubGameHandler
      SubGameHandler::Deque(device_data);

      // WarmupDirectAndIndirectHandler
      WarmupDirectAndIndirectHandler::OnPresent();

      //reset cb_luma_global_settings.GameSettings.UIBlurDown0Count
      cb_luma_global_settings.GameSettings.UIBlurDown0Count = 0; // will apply start of next frame
      
      // reset device_data.has_drawn_main_post_processing
      device_data.has_drawn_main_post_processing = false;
   }

   void LoadConfigs() override
   {
      // cb
      reshade::get_config_value(nullptr, NAME, "Bloom", cb_luma_global_settings.GameSettings.Bloom);
      reshade::get_config_value(nullptr, NAME, "FilmGrain", cb_luma_global_settings.GameSettings.FilmGrain);
      reshade::get_config_value(nullptr, NAME, "WhiteClip", cb_luma_global_settings.GameSettings.WhiteClip);

#if HALO_UPGRADE_SAMPLERS
      // mip_lod_bias_offset
      reshade::get_config_value(nullptr, NAME, "mip_lod_bias_offset", mip_lod_bias_offset);
      SetMipLodBiasOffset(mip_lod_bias_offset, false);
#endif
      
      // allow_gamma_slider
      reshade::get_config_value(nullptr, NAME, "allow_gamma_slider", allow_gamma_slider);

      // custom_sdr_gamma
      // custom_sdr_gamma
      reshade::get_config_value(nullptr, NAME, "custom_sdr_gamma", custom_sdr_gamma);
      ShaderDefines::Set(GAMMA_CORRECTION_TYPE_HASH, custom_sdr_gamma > 0);
      defines_need_recompilation = true;

      //Reset ALLOW_COLORGRADE
      ShaderDefines::Set(ShaderDefines::ALLOW_COLORGRADE, true);

      // SubGameUserSettingsHandler
      SubGameUserSettingsHandler::OnLoadConfigs();
   }
   
   void PrintImGuiAbout() override
   {
      
   }

   void DrawImGuiSettings(DeviceData& device_data) override
   {
      // GameDeviceDataHaloTMCC* game_device_data = static_cast<GameDeviceDataHaloTMCC*>(device_data.game);

      // SWAPCHAIN_TEST_PEAK
      ShaderDefines::UIToggleCheckmark(ShaderDefines::SWAPCHAIN_TEST_PEAK, "Display Peak Test Pattern", "3 rectangles within a bigger one.\n- Left: Invisible (2x Peak)\n- Middle: Barely Visible (1x Peak)\n- Right: Easily Visible (0.5x Peak).\nSo whatever you do, don't let Middle disappear!");

      ImGui::Separator();
      
      auto DrawColoredSubHeader = [](const char* label, const ImVec4& color = ImColor(128, 255, 255, 255))
      {
         ImGui::PushStyleColor(ImGuiCol_Text, color);
         ImGui::Text("[%s]", label);
         ImGui::PopStyleColor();
      };

      // Anti-Aliasing
      if (ImGui::CollapsingHeader("Anti-Aliasing"))
      {
         DrawColoredSubHeader("Turn it on!");
         ImGui::PushStyleColor(ImGuiCol_Text, GetPulsingColor(ImColor(255, 255, 128, 255), 0.05));
         ImGui::Bullet(); ImGui::SameLine(); ImGui::TextWrapped("Please turn on in-game Anti-Aliasing! Then use toggle below.");
         ImGui::PopStyleColor();
         ImGui::Bullet(); ImGui::SameLine(); ImGui::TextWrapped("(This doubles as UI Paper White scaling & also HDR Tonemap for some.)");
         ShaderDefines::UIToggleCheckmark(ShaderDefines::ALLOW_AA, "Allow Anti-Aliasing (FXAA)", "Disable will skip original FXAA code.");
      }

      // Gamma
      if (ImGui::CollapsingHeader("Gamma"))
      {
         DrawColoredSubHeader("In-Game Gamma Sliders");
         ImGui::Bullet(); ImGui::SameLine(); ImGui::TextWrapped("If allowed, any value besides 6.0 will shift Peak!");
         // ImGui::Bullet(); ImGui::SameLine(); ImGui::TextWrapped("\"Reset Gamma Ramp\" above can fully neutralize the game's use of hardware gamma ramp.");

         if (ImGui::Checkbox("Allow In-Game Gamma Sliders", &allow_gamma_slider))
            reshade::set_config_value(nullptr, NAME, "allow_gamma_slider", allow_gamma_slider);
         if (ImGui::IsItemHovered(ImGuiHoveredFlags_AllowWhenDisabled))
            ImGui::SetTooltip("Leaving this disabled will let main color be unaltered sRGB.");
         DrawResetButton(allow_gamma_slider, false, "allow_gamma_slider", nullptr);

         ImGui::NewLine();
         
         DrawColoredSubHeader("Gamma Correct / SDR EOTF Emulation");
         ImGui::Bullet(); ImGui::SameLine(); ImGui::TextWrapped("Reintroduce SDR gamma mismatch to lower shadows, probably matching original intent.");

         // custom_sdr_gamma
         const char* const items[] = { "Off (sRGB)", "Match SDR (2.2)", "Stronger (2.4)", "Xbox Like (2.6)" };
         int custom_sdr_gamma_index = 0;
         if (custom_sdr_gamma > 0) { //detect
            if (custom_sdr_gamma == 2.2f) custom_sdr_gamma_index = 1;
            else if (custom_sdr_gamma == 2.4f) custom_sdr_gamma_index = 2;
            else if (custom_sdr_gamma == 2.6f) custom_sdr_gamma_index = 3;
         }
         ImGui::PushID("GammaCorrection custom_sdr_gamma");
         if (ImGui::Combo("Correction", &custom_sdr_gamma_index, items, IM_ARRAYSIZE(items))) //user set & save
         {
            switch (custom_sdr_gamma_index)
            {
               default: custom_sdr_gamma = 0.f; break;
               case 1: custom_sdr_gamma = 2.2f; break;
               case 2: custom_sdr_gamma = 2.4f; break;
               case 3: custom_sdr_gamma = 2.6f; break;
            }
            reshade::set_config_value(nullptr, NAME, "custom_sdr_gamma", custom_sdr_gamma);
         }
         ImGui::PopID();
      }
      ShaderDefines::Set(GAMMA_CORRECTION_TYPE_HASH, custom_sdr_gamma > 0); // Forced

#if HALO_UPGRADE_SAMPLERS
      // Upgraded Samplers
      if (ImGui::CollapsingHeader("Upgraded Samplers"))
      {
         DrawColoredSubHeader("Increase Texture Sharpness at a Distance");
         
         if (ImGui::SliderFloat("Mip LOD Bias Offset", &mip_lod_bias_offset, 0.f, -10.f, "%.2f"))
            SetMipLodBiasOffset(mip_lod_bias_offset, true);
         if (ImGui::IsItemHovered(ImGuiHoveredFlags_AllowWhenDisabled))
            ImGui::SetTooltip("Negative offset bias sharpens.\nMight make the game too coarse");
         DrawResetButton(mip_lod_bias_offset, 0.f, "mip_lod_bias_offset", nullptr);
      }
#endif
      
      // Miscellaneous
      if (ImGui::CollapsingHeader("Miscellaneous"))
      {
         DrawColoredSubHeader("Miscellaneous Post Processing");

         //Bloom
         auto GetMaxBloomBySubGame = [](SubGame state) -> float
         {
            switch (state)
            {
               case Halo2Classic: return 1.f;
               default: return 2.f;
            }
         };
         if (ImGui::SliderFloat("Bloom", &cb_luma_global_settings.GameSettings.Bloom, 0.f, GetMaxBloomBySubGame(SubGameHandler::curr), "%.2f"))
            reshade::set_config_value(nullptr, NAME, "Bloom", cb_luma_global_settings.GameSettings.Bloom);
         if (ImGui::IsItemHovered(ImGuiHoveredFlags_AllowWhenDisabled))
            ImGui::SetTooltip("Multiplier on Bloom strength.");
         DrawResetButton(cb_luma_global_settings.GameSettings.Bloom, 1.f, "Bloom", nullptr);

         ShaderDefines::UIDropDown(ShaderDefines::HALO3_BLOOM, "Halo 3 Bloom Mode", { "Saturation Preserved", "Blown Out (Vanilla)" }, "How should bloom be processed in Halo 3?\nSince bloom bathes the screen, this can the change the hues of the whole image.");

         if (ImGui::SliderFloat("Film Grain", &cb_luma_global_settings.GameSettings.FilmGrain, 0.f, 1.f, "%.2f"))
            reshade::set_config_value(nullptr, NAME, "FilmGrain", cb_luma_global_settings.GameSettings.FilmGrain);
         if (ImGui::IsItemHovered(ImGuiHoveredFlags_AllowWhenDisabled))
            ImGui::SetTooltip("Multiplier on Film Grain strength.");
         DrawResetButton(cb_luma_global_settings.GameSettings.FilmGrain, 1.f, "FilmGrain", nullptr);

         // WhiteClip
         if (SubGameHandler::curr == Halo4) ImGui::BeginDisabled();
         if (ImGui::SliderFloat("White Clip", &cb_luma_global_settings.GameSettings.WhiteClip, 0.f, 2.f, "%.2f"))
            reshade::set_config_value(nullptr, NAME, "WhiteClip", cb_luma_global_settings.GameSettings.WhiteClip);
         if (ImGui::IsItemHovered(ImGuiHoveredFlags_AllowWhenDisabled))
            ImGui::SetTooltip("Increase to straighten tonemap rolloff,\nmaking highlights more aggressive/clipped.");
         DrawResetButton(cb_luma_global_settings.GameSettings.WhiteClip, 1.f, "WhiteClip", nullptr);
         if (SubGameHandler::curr == Halo4) ImGui::EndDisabled();

         //ALLOW_COLORGRADE
         ShaderDefines::UIToggleCheckmark(ShaderDefines::ALLOW_COLORGRADE, "Color Grading (Debug)", "Disable to skip color grading,\nexposing the raw HDR input after rolloff.");
      }
      
      // SubGame
      if (ImGui::CollapsingHeader("Sub Game"))
      {
         DrawColoredSubHeader("Detects which Halo is actually running.");

         ImGui::Bullet(); ImGui::SameLine(); ImGui::TextWrapped("Current: %s", SubGameToString(SubGameHandler::curr));

         auto compat = SubGameUserSettingsHandler::GetSettings(SubGameHandler::curr)->GetCompatibility();
         ImGui::PushStyleColor(ImGuiCol_Text, compat.second);
         ImGui::Bullet(); ImGui::SameLine(); ImGui::TextWrapped("Compatibility: %s", compat.first);
         ImGui::PopStyleColor();

         //drop down list to override
         static std::vector<const char*> subgame_items = {
            "No Override",
            SubGameToString(Halo1Classic),
            SubGameToString(Halo1Anniversary),
            SubGameToString(Halo2Classic),
            SubGameToString(Halo2Anniversary),
            SubGameToString(Halo2AnniversaryMP),
            SubGameToString(Halo3),
            SubGameToString(Halo3ODST),
            SubGameToString(HaloReach),
            SubGameToString(Halo4),
         };
         int subgame_index = SubGameHandler::over;
         if (ImGui::Combo("Override Sub Game", &subgame_index, subgame_items.data(), static_cast<int>(subgame_items.size())))
         {
            SubGameHandler::over = static_cast<SubGame>(subgame_index);
            SubGameHandler::SetSubGame(static_cast<SubGame>(subgame_index));
         }

         // Reset button
         if (ImGui::Button("Panic Reset")) SubGameHandler::Reinit();
         if (ImGui::IsItemHovered(ImGuiHoveredFlags_AllowWhenDisabled))
            ImGui::SetTooltip("Full reset SubGame detection, clearing all HDR upgraded resources.");

         // best_resource_unorm_disallow
         if (DEVELOPMENT)
         {
            ImGui::Checkbox("(DEVELOPMENT) best_resource_unorm_disallow", &SubGameHandler::best_resource_unorm_disallow);
            if (ImGui::IsItemHovered(ImGuiHoveredFlags_AllowWhenDisabled))
               ImGui::SetTooltip("Disable GetBestResourceUpgradeFormat() UNORM for all Sub Games.");
         }

         ImGui::NewLine();
         
         // SubGameUserSettingsHandler
         DrawColoredSubHeader("Settings Applying On Change");
         SubGameUserSettingsHandler::OnImGui();
      }

      if (DEVELOPMENT) ImGui::Separator();
   }
};

BOOL APIENTRY DllMain(HMODULE hModule, DWORD ul_reason_for_call, LPVOID lpReserved)
{
   switch (ul_reason_for_call)
   {
      case DLL_PROCESS_ATTACH:
         Globals::SetGlobals(PROJECT_NAME, "Halo: The Master Chief Collection - Luma mod"); 
         Globals::VERSION = 1;

         // swapchain
         swapchain_format_upgrade_type  = TextureFormatUpgradesType::AllowedEnabled;
         swapchain_upgrade_type = SwapchainUpgradeType::scRGB;

         // resources
         texture_format_upgrades_type = TextureFormatUpgradesType::AllowedEnabled; //see SubGameHandler::SetSubGame()

#if HALO_UPGRADE_SAMPLERS
         // samplers
         enable_samplers_upgrade = true;
#endif
      
         // // gamma ramp
         // allow_disabling_gamma_ramp = true;

         // // ui separation
         // enable_ui_separation = true;
         // ui_separation_format = DXGI_FORMAT_R16G16B16A16_FLOAT;

         // CREATE!
         game = new GameHaloTMCC();
         break;
      case DLL_PROCESS_DETACH:
         break;
      default:
         break;
   }

   CoreMain(hModule, ul_reason_for_call, lpReserved);

   return TRUE;
}