#define GAME_CODDX11 1

#include "..\..\Core\core.hpp"
// #pragma comment(lib, "comctl32.lib")

namespace Globals
{
   static bool imgui_is_advanced = false;
   static bool pipeline_is_ui = true;
   static bool pipeline_is_fsblur = true;
   
   static float InverseLerp(float a, float b, float v)
   {
      if (a == b) return 0.f;
      return (v - a) / (b - a);
   }
}

namespace ShaderDefineInfo
{
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
      
   int UIDropDown(uint32_t d, const char* label, const char* const items[], const char* tooltip)
   {
      int def = Get(d);
      bool c = ImGui::Combo(label, &def, items, IM_ARRAYSIZE(items));
      if (c) Set(d, def);
      if (ImGui::IsItemHovered(ImGuiHoveredFlags_AllowWhenDisabled)) ImGui::SetTooltip(tooltip);
      UIResetButton(d);
      return def;
   }

   int UIDropDown(uint32_t d, const char* label, std::initializer_list<const char*> items_list, const char* tooltip)
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

namespace GameIdentity
{
   enum Game
   {
      Unknown = 0,
      h1 = 1,
      h2 = 2,
   };
   static Game game = Unknown;

   Game OnDllMain()
   {
      // reset
      game = Unknown;
      if (DEVELOPMENT) ASSERT_MSG(false, "(GameIdentity) Identifying game..");

      // GetModuleFileNameA
      if (game == Unknown)
      {
         char path[MAX_PATH];
         if (GetModuleFileNameA(NULL, path, MAX_PATH) == 0) {
            ASSERT_MSGF(game != Unknown, "Game not identified! (GetModuleFileNameA() == 0)", path);
            return game;
         }
      
         // get filename from path
         const char* filename = strrchr(path, '\\');
         if (filename) filename++;
         else filename = path;
      
         //h1_sp64_ship.exe
         if (_stricmp(filename, "h1_sp64_ship.exe") == 0)
         {
            game = Game::h1;
            if (DEVELOPMENT) ASSERT_MSG(false, "(GameIdentity) Found Modern Warfare Remastered.");
         }
      }

      //TODO: other ways if needed
      if (game == Unknown)
      {
         
      }

      // // Give up, ask user directly
      // if (game == Unknown)
      // {
      //    constexpr int ID_GAME_H1 = 101;
      //    constexpr int ID_GAME_H2 = 102;
      //
      //    const TASKDIALOG_BUTTON buttons[] = {
      //       { ID_GAME_H1, L"Modern Warfare 1 Remastered (H1)" },
      //          { ID_GAME_H2, L"Modern Warfare 2 Remastered (H1)" },
      //   };
      //
      //    TASKDIALOGCONFIG config  = {};
      //    config.cbSize             = sizeof(config);
      //    config.hwndParent         = NULL;
      //    config.dwFlags            = TDF_ALLOW_DIALOG_CANCELLATION | TDF_USE_COMMAND_LINKS;
      //    config.pszWindowTitle     = L"Luma - Select Game";
      //    config.pszMainInstruction = L"Game could not be identified automatically";
      //    config.pszContent         = L"Please select the game:";
      //    config.pButtons           = buttons;
      //    config.cButtons           = ARRAYSIZE(buttons);
      //    config.nDefaultButton     = ID_GAME_H1;
      //
      //    int nButton = IDCANCEL;
      //    TaskDialogIndirect(&config, &nButton, nullptr, nullptr);
      //
      //    switch (nButton)
      //    {
      //    case ID_GAME_H1: game = Game::h1; break;
      //    default: break;
      //    }
      // }

      // Unknown
      ASSERT_MSG(game != Unknown, "Game not identified!");

      //TODO save identification

      return game;
   }
}

namespace GameH1
{
   struct GameDeviceData_H1 final : public GameDeviceData
   {
   
   };
   
   DrawOrDispatchOverrideType OnDrawOrDispatch(ID3D11Device* native_device, ID3D11DeviceContext* native_device_context, CommandListData& cmd_list_data, DeviceData& device_data, reshade::api::shader_stage stages, const ShaderHashesList<OneShaderPerPipeline>&  original_shader_hashes, bool is_custom_pass, bool& updated_cbuffers, std::function<void()>* original_draw_dispatch_func)
   {
      //TODO
      return DrawOrDispatchOverrideType::None;
   }
}

class CallOfDutyDX11 final : public Game
{
public:
   void OnInit(bool async) override
   {
      message(reshade::log::level::info, "OnInit()");

      luma_settings_cbuffer_index = 13;
      luma_data_cbuffer_index = 12;
   }

   void OnCreateDevice(ID3D11Device* native_device, DeviceData& device_data) override
   {
      message(reshade::log::level::info, "OnCreateDevice()");

      // device_data.game
      switch (GameIdentity::game)
      {
         case GameIdentity::Game::h1:
            message(reshade::log::level::info, "(OnCreateDevice) Creating GameDeviceData_H1");
            device_data.game = new GameH1::GameDeviceData_H1;
            break;
         default:
            ASSERT_MSG(false, "Unknown game identity, cannot create game-specific device data.");
            break;
      }
   }

   void OnInitSwapchain(reshade::api::swapchain* swapchain) override
   {
      message(reshade::log::level::info, "OnInitSwapchain()");
   }

   DrawOrDispatchOverrideType OnDrawOrDispatch(ID3D11Device* native_device, ID3D11DeviceContext* native_device_context, CommandListData& cmd_list_data, DeviceData& device_data, reshade::api::shader_stage stages, const ShaderHashesList<OneShaderPerPipeline>&  original_shader_hashes, bool is_custom_pass, bool& updated_cbuffers, std::function<void()>* original_draw_dispatch_func) override
   {
      switch (GameIdentity::game)
      {
         case GameIdentity::Game::h1:
            return GameH1::OnDrawOrDispatch(native_device, native_device_context, cmd_list_data, device_data, stages, original_shader_hashes, is_custom_pass, updated_cbuffers, original_draw_dispatch_func);
         default:
            return DrawOrDispatchOverrideType::None;
      }
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

      // GameIdentity
      GameIdentity::OnDllMain();
      
      texture_format_upgrades_type   = TextureFormatUpgradesType::AllowedEnabled;
      texture_upgrade_formats = {
         reshade::api::format::r8g8b8a8_typeless,
         reshade::api::format::r8g8b8a8_unorm,
         reshade::api::format::r11g11b10_float,
      };
      //enable_indirect_texture_format_upgrades = true;
      texture_format_upgrades_2d_size_filters = 0 | (uint32_t)TextureFormatUpgrades2DSizeFilters::SwapchainResolution | (uint32_t)TextureFormatUpgrades2DSizeFilters::SwapchainAspectRatio;

      game = new CallOfDutyDX11();
   }

   CoreMain(hModule, ul_reason_for_call, lpReserved);

   return TRUE;
}