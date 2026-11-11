#pragma once

#include <atomic>
#include <bit>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <map>
#include <memory>
#include <optional>
#include <string>
#include <vector>

namespace ShadowPatch
{
   inline bool enabled = true;
   inline int taps = 16;
   constexpr int rotation_mode = 1;
   inline std::atomic<uint32_t> patched_compute_shaders{ 0 };
   inline std::atomic<uint32_t> patched_pixel_shaders{ 0 };
   inline std::atomic<uint32_t> patched_shaders_8_taps{ 0 };
   inline std::atomic<uint32_t> failed_shaders{ 0 };

   namespace
   {
      constexpr uint32_t OP_DP2 = 15, OP_ENDLOOP = 22, OP_IGE = 33, OP_LOOP = 48, OP_MAD = 50, OP_CUSTOMDATA = 53, OP_MOV = 54, OP_SAMPLE_C_LZ = 71, OP_SINCOS = 77, OP_UGE = 80;
      constexpr uint32_t OT_TEMP = 0, OT_IMM32 = 4, OT_IMM64 = 5, OT_CBUFFER = 8, OT_ICB = 9;
      constexpr uint32_t CUSTOMDATA_CLASS_ICB = 3;

      constexpr uint32_t F2U(float f) { return std::bit_cast<uint32_t>(f); }
      inline float U2F(uint32_t u) { return std::bit_cast<float>(u); }

      constexpr float VANILLA_KERNEL[8][2] = { {-0.80811429f, 0.80811429f}, {0.f, -1.f}, {0.60605717f, 0.60605717f}, {-0.71428573f, 0.f}, {0.40411428f, -0.40411428f}, {0.f, 0.42857143f}, {-0.20205714f, -0.20205714f}, {0.14285715f, 0.f} };
      constexpr uint32_t VANILLA_KERNEL_FIRST_BITS = F2U(-0.80811429f);
      constexpr uint32_t TWO_PI_BITS = F2U(6.28318548f);
      constexpr uint32_t WEIGHT_8_BITS = F2U(0.125f);

      struct Index
      {
         enum Kind : uint8_t { Imm, Imm64, Rel, ImmRel, Imm64Rel } kind = Imm;
         uint32_t value = 0;
      };

      struct Operand
      {
         size_t start = 0, end = 0;
         uint32_t type = 0, ncomp = 0, sel = 0, swz = 0;
         uint32_t imm[8] = {};
         uint32_t imm_count = 0;
         Index indices[3] = {};
         uint32_t index_count = 0;

         bool IsImm32(uint32_t value) const { return type == OT_IMM32 && imm_count == 1 && imm[0] == value; }
         int64_t TempReg() const { return (type == OT_TEMP && index_count >= 1 && indices[0].kind == Index::Imm) ? int64_t(indices[0].value) : -1; }
      };

      struct Insn
      {
         size_t start = 0, end = 0;
         uint32_t op = 0;
         uint32_t custom_class = 0;
         std::vector<Operand> operands;
      };

      bool ParseOperand(const std::vector<uint32_t>& w, size_t& i, Operand& o, int depth = 0)
      {
         if (i >= w.size() || depth > 2) return false;
         o.start = i;
         const uint32_t tok = w[i++];
         o.ncomp = tok & 3;
         o.sel = (tok >> 2) & 3;
         o.swz = (tok >> 4) & 0xFF;
         o.type = (tok >> 12) & 0xFF;
         const uint32_t dim = (tok >> 20) & 3;
         const uint32_t reps[3] = { (tok >> 22) & 7, (tok >> 25) & 7, (tok >> 28) & 7 };
         uint32_t ext = tok >> 31;
         while (ext)
         {
            if (i >= w.size()) return false;
            ext = w[i++] >> 31;
         }
         if (o.type == OT_IMM32)
         {
            o.imm_count = (o.ncomp == 1) ? 1 : 4;
         }
         else if (o.type == OT_IMM64)
         {
            o.imm_count = (o.ncomp == 1) ? 2 : 8;
         }
         for (uint32_t k = 0; k < o.imm_count; k++)
         {
            if (i >= w.size()) return false;
            o.imm[k] = w[i++];
         }
         for (uint32_t d = 0; d < dim; d++)
         {
            Index idx;
            Operand sub;
            switch (reps[d])
            {
            case 0: if (i >= w.size()) return false; idx.kind = Index::Imm; idx.value = w[i++]; break;
            case 1: if (i + 1 >= w.size()) return false; idx.kind = Index::Imm64; idx.value = w[i]; i += 2; break;
            case 2: idx.kind = Index::Rel; if (!ParseOperand(w, i, sub, depth + 1)) return false; break;
            case 3: if (i >= w.size()) return false; idx.kind = Index::ImmRel; idx.value = w[i++]; if (!ParseOperand(w, i, sub, depth + 1)) return false; break;
            case 4: if (i + 1 >= w.size()) return false; idx.kind = Index::Imm64Rel; idx.value = w[i]; i += 2; if (!ParseOperand(w, i, sub, depth + 1)) return false; break;
            default: return false;
            }
            o.indices[o.index_count++] = idx;
         }
         o.end = i;
         return true;
      }

      bool Parse(const std::vector<uint32_t>& words, std::vector<Insn>& insns)
      {
         const size_t n = words.size();
         size_t i = 0;
         while (i < n)
         {
            const uint32_t tok = words[i];
            Insn ins;
            ins.start = i;
            ins.op = tok & 0x7FF;
            if (ins.op == OP_CUSTOMDATA)
            {
               if (i + 1 >= n) return false;
               ins.custom_class = tok >> 11;
               ins.end = i + words[i + 1];
            }
            else
            {
               ins.end = i + ((tok >> 24) & 0x7F);
               size_t j = i + 1;
               uint32_t ext = tok >> 31;
               while (ext)
               {
                  if (j >= n) return false;
                  ext = words[j++] >> 31;
               }
               while (j < ins.end)
               {
                  Operand o;
                  size_t j2 = j;
                  if (!ParseOperand(words, j2, o) || j2 > ins.end) break;
                  ins.operands.push_back(o);
                  j = j2;
               }
            }
            if (ins.end <= i || ins.end > n) return false;
            i = ins.end;
            insns.push_back(std::move(ins));
         }
         return true;
      }

      std::vector<uint32_t> MakeMovImm(const std::vector<uint32_t>& words, const Operand& dst, uint32_t value_bits)
      {
         std::vector<uint32_t> out;
         const uint32_t length = uint32_t(1 + (dst.end - dst.start) + 2);
         out.push_back(OP_MOV | (length << 24));
         out.insert(out.end(), words.begin() + dst.start, words.begin() + dst.end);
         out.push_back(0x00004001);
         out.push_back(value_bits);
         return out;
      }

      std::vector<uint32_t> MakeMul(const std::vector<uint32_t>& words, const Operand& dst, const Operand& src0, const Operand& src1)
      {
         constexpr uint32_t OP_MUL = 56;
         std::vector<uint32_t> out;
         const uint32_t length = uint32_t(1 + (dst.end - dst.start) + (src0.end - src0.start) + (src1.end - src1.start));
         out.push_back(OP_MUL | (length << 24));
         out.insert(out.end(), words.begin() + dst.start, words.begin() + dst.end);
         out.insert(out.end(), words.begin() + src0.start, words.begin() + src0.end);
         out.insert(out.end(), words.begin() + src1.start, words.begin() + src1.end);
         return out;
      }

      void Vogel(uint32_t n, std::vector<uint32_t>& out_xy00, double scale = 1.1)
      {
         for (uint32_t i = 0; i < n; i++)
         {
            const double r = std::sqrt((double(i) + 0.5) / double(n)) * scale;
            const double t = double(i) * 2.39996323;
            out_xy00.push_back(F2U(float(r * std::cos(t))));
            out_xy00.push_back(F2U(float(r * std::sin(t))));
            out_xy00.push_back(F2U(0.f));
            out_xy00.push_back(F2U(0.f));
         }
      }
   }

   struct Result
   {
      std::vector<uint32_t> words;
      uint32_t loops = 0;
      uint32_t angle_producers = 0;
      uint32_t taps = 0;
      uint32_t icb_entries_before = 0;
      uint32_t icb_entries_after = 0;
   };

   inline bool HasVanillaKernel(const uint32_t* words, size_t count)
   {
      for (size_t i = 0; i < count; i++)
         if (words[i] == VANILLA_KERNEL_FIRST_BITS) return true;
      return false;
   }

   inline std::optional<Result> Patch(const std::vector<uint32_t>& words, int requested_taps, int rotation, std::string* log = nullptr)
   {
      auto fail = [&](const char* why) -> std::optional<Result> { if (log) *log = why; return std::nullopt; };

      std::vector<Insn> insns;
      if (!Parse(words, insns)) return fail("malformed instruction stream");

      const Insn* icb = nullptr;
      for (const auto& x : insns)
      {
         if (x.op == OP_CUSTOMDATA && x.custom_class == CUSTOMDATA_CLASS_ICB)
         {
            if (icb) return fail("more than one icb");
            icb = &x;
         }
      }
      if (!icb) return fail("no icb");
      const size_t vals_start = icb->start + 2;
      const size_t vals_count = icb->end - vals_start;
      const uint32_t entries = uint32_t(vals_count / 4);
      auto entry = [&](uint32_t k, uint32_t c) { return U2F(words[vals_start + 4 * k + c]); };
      auto matches = [&](uint32_t base)
      {
         if (base + 8 > entries) return false;
         for (uint32_t k = 0; k < 8; k++)
            if (std::fabs(entry(base + k, 0) - VANILLA_KERNEL[k][0]) >= 1e-5f || std::fabs(entry(base + k, 1) - VANILLA_KERNEL[k][1]) >= 1e-5f) return false;
         return true;
      };
      int64_t base = -1;
      for (uint32_t b = 0; b + 8 <= entries; b++)
      {
         if (matches(b))
         {
            if (base >= 0) return fail("vanilla kernel found twice in the icb");
            base = b;
         }
      }
      if (base < 0) return fail("vanilla kernel not found in the icb");

      uint32_t taps = (requested_taps == 32) ? 32 : (requested_taps == 16) ? 16 : 8;
      const bool extend = (taps > 8 && entries == uint32_t(base) + 8);
      if (taps > 8 && !extend) taps = 8;
      std::vector<uint32_t> new_vals(words.begin() + vals_start, words.begin() + vals_start + 4 * size_t(base));
      Vogel(taps, new_vals);
      new_vals.insert(new_vals.end(), words.begin() + vals_start + 4 * (size_t(base) + 8), words.begin() + icb->end);

      std::map<size_t, std::vector<uint32_t>> edits;
      std::vector<size_t> stack;
      uint32_t patched_loops = 0;
      for (size_t idx = 0; idx < insns.size(); idx++)
      {
         const auto& ins = insns[idx];
         if (ins.op == OP_LOOP) { stack.push_back(idx); continue; }
         if (ins.op != OP_ENDLOOP) continue;
         if (stack.empty()) return fail("unbalanced loops");
         const size_t a = stack.back(); stack.pop_back();
         const size_t b = idx;

         std::vector<size_t> dp2;
         bool has_sample_c = false;
         for (size_t k = a + 1; k < b; k++)
         {
            const auto& x = insns[k];
            if (x.op == OP_DP2 && x.operands.size() == 3 && x.operands[1].type == OT_ICB) dp2.push_back(k);
            if (x.op == OP_SAMPLE_C_LZ) has_sample_c = true;
         }
         if (dp2.size() != 2 || !has_sample_c) continue;

         const Operand& icb_op = insns[dp2[0]].operands[1];
         int64_t loop_base = -1;
         if (icb_op.index_count == 1 && icb_op.indices[0].kind == Index::ImmRel) loop_base = icb_op.indices[0].value;
         else if (icb_op.index_count == 1 && icb_op.indices[0].kind == Index::Rel) loop_base = 0;
         if (loop_base != base) return fail("shadow loop icb base mismatch");

         std::vector<size_t> bound, weight;
         for (size_t k = a + 1; k < b; k++)
         {
            const auto& x = insns[k];
            if (x.op == OP_UGE || x.op == OP_IGE)
               for (const auto& o : x.operands) if (o.IsImm32(8)) { bound.push_back(k); break; }
            if (x.op == OP_MAD)
               for (const auto& o : x.operands) if (o.IsImm32(WEIGHT_8_BITS)) { weight.push_back(k); break; }
         }
         if (bound.size() != 1 || weight.size() != 1) return fail("shadow loop bound/weight not found");
         if (taps > 8)
         {
            const struct { size_t k; uint32_t old_bits, new_bits; } fixes[2] = { { bound[0], 8u, taps }, { weight[0], WEIGHT_8_BITS, F2U(1.0f / float(taps)) } };
            for (const auto& f : fixes)
            {
               const auto& x = insns[f.k];
               std::vector<uint32_t> ws(words.begin() + x.start, words.begin() + x.end);
               for (const auto& o : x.operands)
                  if (o.IsImm32(f.old_bits)) ws[o.start + 1 - x.start] = f.new_bits;
               edits[f.k] = std::move(ws);
            }
         }
         patched_loops++;
      }
      if (patched_loops == 0) return fail("no shadow loops");

      uint32_t angles = 0;
      for (size_t idx = 0; idx < insns.size(); idx++)
      {
         const auto& x = insns[idx];
         if (x.op != OP_MAD || x.operands.size() != 4) continue;
         if (!x.operands[2].IsImm32(TWO_PI_BITS) || x.operands[3].type != OT_CBUFFER) continue;
         const int64_t dst = x.operands[0].TempReg();
         if (dst < 0) continue;
         bool feeds_sincos = false;
         for (size_t k = idx + 1; k < insns.size() && k < idx + 5 && !feeds_sincos; k++)
         {
            const auto& y = insns[k];
            feeds_sincos = (y.op == OP_SINCOS && y.operands.size() == 3 && y.operands[2].TempReg() == dst);
         }
         if (!feeds_sincos) continue;
         if (rotation == 0) edits[idx] = MakeMovImm(words, x.operands[0], F2U(0.f));
         else if (rotation == 1) edits[idx] = MakeMul(words, x.operands[0], x.operands[1], x.operands[2]);
         angles++;
      }
      if (angles == 0) return fail("dither angle producer not found");

      Result r;
      r.words.reserve(words.size() + 64);
      for (size_t idx = 0; idx < insns.size(); idx++)
      {
         const auto& ins = insns[idx];
         if (auto it = edits.find(idx); it != edits.end())
         {
            r.words.insert(r.words.end(), it->second.begin(), it->second.end());
         }
         else if (&ins == icb)
         {
            r.words.push_back(words[icb->start]);
            r.words.push_back(uint32_t(2 + new_vals.size()));
            r.words.insert(r.words.end(), new_vals.begin(), new_vals.end());
         }
         else
         {
            r.words.insert(r.words.end(), words.begin() + ins.start, words.begin() + ins.end);
         }
      }
      r.loops = patched_loops;
      r.angle_producers = angles;
      r.taps = taps;
      r.icb_entries_before = entries;
      r.icb_entries_after = uint32_t(new_vals.size() / 4);
      return r;
   }

   inline std::unique_ptr<std::byte[]> PatchLumaBytecode(const std::byte* code, size_t& size, reshade::api::pipeline_subobject_type type, uint64_t shader_hash)
   {
      if (code == nullptr || size < 8 || (size % 4) != 0) return nullptr;
      if (type != reshade::api::pipeline_subobject_type::compute_shader && type != reshade::api::pipeline_subobject_type::pixel_shader) return nullptr;
      const uint32_t* words_ptr = reinterpret_cast<const uint32_t*>(code);
      const size_t count = size / 4;
      if (!HasVanillaKernel(words_ptr, count)) return nullptr;

      std::vector<uint32_t> words(words_ptr, words_ptr + count);
      std::string why;
      auto result = Patch(words, taps, rotation_mode, &why);
      if (!result)
      {
         failed_shaders++;
         reshade::log::message(reshade::log::level::warning, std::format("ShadowPatch: shader {:08X} carries the vanilla shadow kernel but was not patched: {}", uint32_t(shader_hash), why).c_str());
         return nullptr;
      }

      const size_t new_size = result->words.size() * 4;
      auto out = std::make_unique<std::byte[]>(new_size);
      std::memcpy(out.get(), result->words.data(), new_size);
      size = new_size;

      if (type == reshade::api::pipeline_subobject_type::compute_shader) patched_compute_shaders++;
      else patched_pixel_shaders++;
      if (result->taps < uint32_t(taps)) patched_shaders_8_taps++;
      reshade::log::message(reshade::log::level::info, std::format("ShadowPatch: {} shader {:08X} patched ({} shadow loops, {} angle producers, icb {} -> {} entries, {} taps, rotation mode {}, {} -> {} dwords)",
         type == reshade::api::pipeline_subobject_type::compute_shader ? "compute" : "pixel", uint32_t(shader_hash), result->loops, result->angle_producers, result->icb_entries_before, result->icb_entries_after, result->taps, rotation_mode, count, result->words.size()).c_str());
      return out;
   }
}
