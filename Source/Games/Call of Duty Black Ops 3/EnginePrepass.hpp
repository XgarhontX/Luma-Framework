#pragma once

#include <array>
#include <atomic>
#include <cstdint>
#include <cstring>
#include <string>
#include <vector>
#include <Windows.h>

namespace EnginePrepass
{
   constexpr bool enabled = true;
   constexpr uint32_t list_mask = 0x3F;
   constexpr uint32_t SELECTABLE_LISTS = 24;

   struct Entry
   {
      int32_t list = 0;
      uint8_t flag = 0;
      uint8_t pad[3] = {};
   };
   static_assert(sizeof(Entry) == 8);
   struct TableEntry
   {
      const Entry* entries;
      uint32_t count;
      uint32_t pad;
   };
   static_assert(sizeof(TableEntry) == 16);
   constexpr uint32_t PREPASS_TYPE = 2;

   enum class Status { NotScanned, ModuleNotFound, PatternNotFound, UnexpectedTable, Ready };
   inline Status status = Status::NotScanned;
   inline std::string status_text = "not scanned";
   inline TableEntry* table = nullptr;
   inline TableEntry original = {};
   inline std::vector<Entry> vanilla_entries;
   inline std::array<std::vector<Entry>, 2> buffers;
   inline uint32_t live_buffer = 0;
   inline bool applied = false;
   inline uint32_t applied_count = 0;

   namespace
   {
      bool FindTextSection(uintptr_t base, uintptr_t& start, size_t& size)
      {
         const auto* dos = reinterpret_cast<const IMAGE_DOS_HEADER*>(base);
         if (dos->e_magic != IMAGE_DOS_SIGNATURE) return false;
         const auto* nt = reinterpret_cast<const IMAGE_NT_HEADERS64*>(base + dos->e_lfanew);
         if (nt->Signature != IMAGE_NT_SIGNATURE) return false;
         const IMAGE_SECTION_HEADER* sections = IMAGE_FIRST_SECTION(nt);
         for (unsigned i = 0; i < nt->FileHeader.NumberOfSections; i++)
         {
            if (std::memcmp(sections[i].Name, ".text", 5) == 0)
            {
               start = base + sections[i].VirtualAddress;
               size = sections[i].Misc.VirtualSize;
               return true;
            }
         }
         for (unsigned i = 0; i < nt->FileHeader.NumberOfSections; i++)
         {
            if (sections[i].Characteristics & IMAGE_SCN_MEM_EXECUTE)
            {
               start = base + sections[i].VirtualAddress;
               size = sections[i].Misc.VirtualSize;
               return true;
            }
         }
         return false;
      }

      constexpr uint8_t PATTERN[] = { 0x48, 0x63, 0x01, 0x48, 0x8D, 0x0D, 0, 0, 0, 0, 0x48, 0x8B, 0xF2, 0x48, 0x03, 0xC0, 0x33, 0xD2, 0x4D, 0x8B, 0xF0, 0x48, 0x8B, 0x1C, 0xC1, 0x8B, 0x7C, 0xC1, 0x08 };
      constexpr bool PATTERN_MASK[] = { 1,1,1,1,1,1, 0,0,0,0, 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1 };
      constexpr size_t LEA_OFFSET = 3;

      uintptr_t ScanPattern(uintptr_t start, size_t size)
      {
         constexpr size_t n = sizeof(PATTERN);
         if (size < n) return 0;
         const uint8_t* p = reinterpret_cast<const uint8_t*>(start);
         for (size_t i = 0; i + n <= size; i++)
         {
            if (p[i] != PATTERN[0]) continue;
            bool ok = true;
            for (size_t k = 1; k < n && ok; k++)
               if (PATTERN_MASK[k] && p[i + k] != PATTERN[k]) ok = false;
            if (ok) return start + i;
         }
         return 0;
      }

      bool WriteEntry(TableEntry* dst, const Entry* entries, uint32_t count, bool growing)
      {
         DWORD old_protect = 0;
         if (!VirtualProtect(dst, sizeof(TableEntry), PAGE_READWRITE, &old_protect)) return false;
         volatile TableEntry* v = dst;
         if (growing) { v->entries = entries; v->count = count; }
         else { v->count = count; v->entries = entries; }
         DWORD tmp = 0;
         VirtualProtect(dst, sizeof(TableEntry), old_protect, &tmp);
         return true;
      }
   }

   inline bool Scan()
   {
      if (status == Status::Ready) return true;
      const uintptr_t base = reinterpret_cast<uintptr_t>(GetModuleHandleA("BlackOps3.exe"));
      if (!base) { status = Status::ModuleNotFound; status_text = "BlackOps3.exe module not found"; return false; }
      uintptr_t text_start = 0; size_t text_size = 0;
      if (!FindTextSection(base, text_start, text_size)) { status = Status::PatternNotFound; status_text = "code section not found"; return false; }
      const uintptr_t hit = ScanPattern(text_start, text_size);
      if (!hit) { status = Status::PatternNotFound; status_text = "prepass draw routine pattern not found (unsupported game version)"; return false; }
      const uintptr_t lea = hit + LEA_OFFSET;
      const int32_t rel = *reinterpret_cast<const int32_t*>(lea + 3);
      auto* candidate = reinterpret_cast<TableEntry*>(lea + 7 + rel);

      auto valid_entry = [](const TableEntry& e, uint32_t count, int32_t a, int32_t b)
      {
         if (e.count != count || e.entries == nullptr) return false;
         if (IsBadReadPtr(e.entries, sizeof(Entry) * count)) return false;
         return e.entries[0].list == a && e.entries[1].list == b;
      };
      if (IsBadReadPtr(candidate, sizeof(TableEntry) * 4) || !valid_entry(candidate[2], 2, 7, 12) || !valid_entry(candidate[3], 2, 8, 13))
      {
         status = Status::UnexpectedTable;
         status_text = std::format("prepass table at {:#x} does not have the expected vanilla contents", reinterpret_cast<uintptr_t>(candidate));
         return false;
      }
      table = candidate;
      original = table[PREPASS_TYPE];
      vanilla_entries.assign(original.entries, original.entries + original.count);
      buffers[0].reserve(SELECTABLE_LISTS + 8);
      buffers[1].reserve(SELECTABLE_LISTS + 8);
      status = Status::Ready;
      status_text = std::format("prepass table found at BlackOps3.exe+{:#x} (routine at +{:#x})", reinterpret_cast<uintptr_t>(candidate) - base, hit - base);
      reshade::log::message(reshade::log::level::info, ("EnginePrepass: " + status_text).c_str());
      return true;
   }

   inline bool Apply()
   {
      if (status != Status::Ready && !Scan()) return false;
      if (!enabled)
      {
         if (applied)
         {
            WriteEntry(&table[PREPASS_TYPE], original.entries, original.count, false);
            applied = false;
            applied_count = original.count;
            reshade::log::message(reshade::log::level::info, "EnginePrepass: vanilla prepass list restored");
         }
         return false;
      }
      std::vector<Entry>& next = buffers[live_buffer ^ 1u];
      next.assign(vanilla_entries.begin(), vanilla_entries.end());
      for (uint32_t i = 0; i < SELECTABLE_LISTS; i++)
      {
         if ((list_mask & (1u << i)) == 0) continue;
         bool present = false;
         for (const auto& e : vanilla_entries) if (e.list == int32_t(i)) present = true;
         if (present) continue;
         Entry e; e.list = int32_t(i); e.flag = 0;
         next.push_back(e);
      }
      const std::vector<Entry>& live = buffers[live_buffer];
      if (applied && live.size() == next.size() && std::memcmp(live.data(), next.data(), live.size() * sizeof(Entry)) == 0) return true;
      const uint32_t live_count = applied ? uint32_t(live.size()) : original.count;
      WriteEntry(&table[PREPASS_TYPE], next.data(), uint32_t(next.size()), next.size() >= live_count);
      live_buffer ^= 1u;
      applied = true;
      applied_count = uint32_t(next.size());
      reshade::log::message(reshade::log::level::info, std::format("EnginePrepass: PREPASS now draws {} surface lists (mask {:#x})", applied_count, list_mask).c_str());
      return true;
   }
}
