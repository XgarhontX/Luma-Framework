#pragma once

#include <algorithm>
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
#include <mutex>
#include <shared_mutex>
#include <unordered_set>
#include <d3d11.h>
#include <wrl/client.h>
#include "ShadowNoise.hpp"

namespace ShadowPatch
{
   inline bool enabled = true;
   constexpr int TAP_OPTIONS[] = { 8, 16, 24, 32, 48, 64, 128 };
   constexpr bool IsValidTapCount(int n) { for (int o : TAP_OPTIONS) if (o == n) return true; return false; }
   inline int taps = 8;
   constexpr int rotation_mode = 3;
   inline std::atomic<uint32_t> patched_compute_shaders{ 0 };
   inline std::atomic<uint32_t> patched_pixel_shaders{ 0 };
   inline std::atomic<uint32_t> patched_shaders_8_taps{ 0 };
   inline std::atomic<uint32_t> failed_shaders{ 0 };
   inline std::shared_mutex patched_mutex;
   inline std::unordered_set<uint32_t> patched_hashes;

   inline bool IsPatched(uint32_t shader_hash)
   {
      if (shader_hash == 0) return false;
      const std::shared_lock lock(patched_mutex);
      return patched_hashes.contains(shader_hash);
   }

   namespace
   {
      constexpr uint32_t OP_AND = 1, OP_DP2 = 15, OP_ENDLOOP = 22, OP_FTOU = 28, OP_IF = 31, OP_IGE = 33, OP_ILT = 34, OP_LD = 45, OP_LOOP = 48, OP_MAD = 50, OP_CUSTOMDATA = 53, OP_MOV = 54, OP_MUL = 56, OP_SAMPLE_C_LZ = 71, OP_SINCOS = 77, OP_ULT = 79, OP_UGE = 80;
      constexpr uint32_t OP_DCL_RESOURCE = 88, OP_DCL_TEMPS = 104, OP_DCL_RESOURCE_RAW = 161, OP_DCL_RESOURCE_STRUCTURED = 162;
      constexpr uint32_t OT_TEMP = 0, OT_IMM32 = 4, OT_IMM64 = 5, OT_RESOURCE = 7, OT_CBUFFER = 8, OT_ICB = 9;
      constexpr uint32_t NOISE_SLOT = 127;
      constexpr uint32_t CONST_SLOT = 126;
      constexpr uint32_t KERNEL_TAPS = 128;
      constexpr uint32_t IGN_X_BITS = 0x3D897143u;
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

      bool SrcScalar(const Operand& o, int64_t& reg, uint32_t& comp)
      {
         reg = o.TempReg();
         if (reg < 0 || (o.sel != 1 && o.sel != 2)) return false;
         comp = o.swz & 3;
         return true;
      }
      bool DstScalar(const Operand& o, int64_t& reg, uint32_t& comp)
      {
         reg = o.TempReg();
         if (reg < 0 || o.sel != 0) return false;
         const uint32_t mask = o.swz & 0xF;
         if (mask == 0 || (mask & (mask - 1)) != 0) return false;
         comp = uint32_t(std::countr_zero(mask));
         return true;
      }

      std::vector<uint32_t> MakeMul(const std::vector<uint32_t>& words, const Operand& dst, const Operand& src0, const Operand& src1)
      {
         std::vector<uint32_t> out;
         const uint32_t length = uint32_t(1 + (dst.end - dst.start) + (src0.end - src0.start) + (src1.end - src1.start));
         out.push_back(OP_MUL | (length << 24));
         out.insert(out.end(), words.begin() + dst.start, words.begin() + dst.end);
         out.insert(out.end(), words.begin() + src0.start, words.begin() + src0.end);
         out.insert(out.end(), words.begin() + src1.start, words.begin() + src1.end);
         return out;
      }

      std::vector<uint32_t> MakeNoiseAngle(const std::vector<uint32_t>& words, const Operand& dst, const Operand& pos, uint32_t scratch)
      {
         std::vector<uint32_t> out;
         auto temp = [&](uint32_t token) { out.push_back(token); out.push_back(scratch); };
         out.push_back(OP_FTOU | (uint32_t(1 + 2 + (pos.end - pos.start)) << 24));
         temp(0x00100032u);
         out.insert(out.end(), words.begin() + pos.start, words.begin() + pos.end);
         out.push_back(OP_AND | (10u << 24));
         temp(0x00100032u); temp(0x00100046u);
         out.insert(out.end(), { 0x00004002u, ShadowNoise::WIDTH - 1, ShadowNoise::HEIGHT - 1, 0u, 0u });
         out.push_back(OP_MOV | (8u << 24));
         temp(0x001000C2u);
         out.insert(out.end(), { 0x00004002u, 0u, 0u, 0u, 0u });
         out.insert(out.end(), { OP_LD | (9u << 24) | 0x80000000u, 0x800000C2u, 0x00155543u });
         temp(0x00100012u); temp(0x00100E46u);
         out.insert(out.end(), { 0x00107E46u, NOISE_SLOT });
         out.push_back(OP_MUL | (uint32_t(1 + (dst.end - dst.start) + 2 + 2) << 24));
         out.insert(out.end(), words.begin() + dst.start, words.begin() + dst.end);
         temp(0x0010000Au);
         out.insert(out.end(), { 0x00004001u, TWO_PI_BITS });
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
      uint32_t cascade_fixes = 0;
      uint32_t flag_forced = 0;
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

      (void)requested_taps;
      const bool extend = (entries == uint32_t(base) + 8);
      uint32_t taps = extend ? KERNEL_TAPS : 8u;
      std::vector<uint32_t> new_vals(words.begin() + vals_start, words.begin() + vals_start + 4 * size_t(base));
      Vogel(taps, new_vals);
      new_vals.insert(new_vals.end(), words.begin() + vals_start + 4 * (size_t(base) + 8), words.begin() + icb->end);

      std::map<size_t, std::vector<uint32_t>> edits;

      size_t dcl_temps_idx = SIZE_MAX, last_dcl_resource = SIZE_MAX, first_code = SIZE_MAX;
      uint32_t sreg = 0;
      for (size_t idx = 0; idx < insns.size(); idx++)
      {
         const auto& x = insns[idx];
         if (x.op == OP_DCL_TEMPS && x.end - x.start == 2) { dcl_temps_idx = idx; sreg = words[x.start + 1]; }
         if (x.op == OP_DCL_RESOURCE || x.op == OP_DCL_RESOURCE_RAW || x.op == OP_DCL_RESOURCE_STRUCTURED)
         {
            if (!x.operands.empty() && x.operands[0].type == OT_RESOURCE && x.operands[0].index_count >= 1 && (x.operands[0].indices[0].value == NOISE_SLOT || x.operands[0].indices[0].value == CONST_SLOT)) return fail("noise / constant texture slot already used");
            if (x.op == OP_DCL_RESOURCE) last_dcl_resource = idx;
         }
         if (first_code == SIZE_MAX && x.op < OP_DCL_RESOURCE && x.op != OP_CUSTOMDATA) first_code = idx;
      }
      if (dcl_temps_idx == SIZE_MAX || last_dcl_resource == SIZE_MAX || first_code == SIZE_MAX || sreg >= 4095) return fail("declarations for the shadow constants not found");
      const uint32_t creg = sreg + 1;
      edits[dcl_temps_idx] = { words[insns[dcl_temps_idx].start], sreg + 2 };
      {
         std::vector<uint32_t> decl(words.begin() + insns[last_dcl_resource].start, words.begin() + insns[last_dcl_resource].end);
         decl.insert(decl.end(), { 0x04001858u, 0x00107000u, CONST_SLOT, 0x00005555u });
         decl.insert(decl.end(), { 0x04001858u, 0x00107000u, NOISE_SLOT, 0x00005555u });
         edits[last_dcl_resource] = std::move(decl);
      }
      if (extend)
      {
         std::vector<uint32_t> load = {
            OP_MOV | (8u << 24), 0x001000F2u, creg, 0x00004002u, 0u, 0u, 0u, 0u,
            OP_LD | (9u << 24) | 0x80000000u, 0x800000C2u, 0x00155543u, 0x001000F2u, creg, 0x00100E46u, creg, 0x00107E46u, CONST_SLOT,
            OP_FTOU | (5u << 24), 0x00100012u, creg, 0x0010000Au, creg };
         load.insert(load.end(), words.begin() + insns[first_code].start, words.begin() + insns[first_code].end);
         edits[first_code] = std::move(load);
      }
      auto c_select = [&](std::vector<uint32_t>& ws, size_t pos, uint32_t comp) { ws[pos] = 0x0010000Au | (comp << 4); ws[pos + 1] = creg; };

      std::vector<size_t> stack;
      uint32_t patched_loops = 0;
      uint32_t cascade_fixes = 0;
      std::vector<size_t> loop_starts;
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
         if (extend)
         {
            const struct { size_t k; uint32_t old_bits, comp; } fixes[2] = { { bound[0], 8u, 0u }, { weight[0], WEIGHT_8_BITS, 1u } };
            for (const auto& f : fixes)
            {
               const auto& x = insns[f.k];
               std::vector<uint32_t> ws(words.begin() + x.start, words.begin() + x.end);
               for (const auto& o : x.operands)
                  if (o.IsImm32(f.old_bits)) c_select(ws, o.start - x.start, f.comp);
               edits[f.k] = std::move(ws);
            }
            int64_t d1 = -1, d2 = -1; uint32_t m1 = 0, m2 = 0;
            if (!DstScalar(insns[dp2[0]].operands[0], d1, m1) || !DstScalar(insns[dp2[1]].operands[0], d2, m2) || d1 != d2) return fail("shadow loop kernel offsets not in one register");
            const uint32_t mask = (1u << m1) | (1u << m2);
            std::vector<uint32_t> ws2(words.begin() + insns[dp2[1]].start, words.begin() + insns[dp2[1]].end);
            ws2.insert(ws2.end(), { OP_MUL | (7u << 24), 0x00100002u | (mask << 4), uint32_t(d1), 0x00100E46u, uint32_t(d1), 0x00100FF6u, creg });
            edits[dp2[1]] = std::move(ws2);

            int64_t counter_reg = -1; uint32_t counter_comp = 0;
            for (size_t oi = 1; oi < insns[bound[0]].operands.size() && counter_reg < 0; oi++)
               if (!SrcScalar(insns[bound[0]].operands[oi], counter_reg, counter_comp)) counter_reg = -1;
            if (counter_reg < 0) return fail("shadow loop counter not found");
            for (size_t k = a + 1; k < b; k++)
            {
               const auto& x = insns[k];
               if (k == bound[0] || x.operands.size() != 3) continue;
               if (x.op != OP_ULT && x.op != OP_ILT && x.op != OP_UGE && x.op != OP_IGE) continue;
               int64_t r1 = -1, r2 = -1; uint32_t c1 = 0, c2 = 0;
               if (!SrcScalar(x.operands[1], r1, c1) || !SrcScalar(x.operands[2], r2, c2)) continue;
               int64_t thr_reg; uint32_t thr_comp;
               if (r2 == counter_reg && c2 == counter_comp) { thr_reg = r1; thr_comp = c1; }
               else if (r1 == counter_reg && c1 == counter_comp) { thr_reg = r2; thr_comp = c2; }
               else continue;
               bool fixed = false;
               for (size_t p = a; p-- > 0 && a - p <= 96;)
               {
                  const auto& y = insns[p];
                  if (y.op == OP_LOOP || y.op == OP_ENDLOOP) break;
                  if (y.op != OP_MUL || y.operands.size() != 3) continue;
                  int64_t dr = -1; uint32_t dc = 0;
                  if (!DstScalar(y.operands[0], dr, dc) || dr != thr_reg || dc != thr_comp) continue;
                  const Operand* imm = nullptr;
                  for (size_t oi = 1; oi < 3; oi++)
                     if (y.operands[oi].type == OT_IMM32 && y.operands[oi].imm_count == 1) imm = &y.operands[oi];
                  if (!imm) return fail("cascade threshold producer has no immediate scale");
                  const float scale = U2F(imm->imm[0]);
                  if (!(scale > 1.f && scale < 1000.f)) return fail("unexpected cascade threshold scale");
                  std::vector<uint32_t> ws(words.begin() + y.start, words.begin() + y.end);
                  c_select(ws, imm->start - y.start, 2u);
                  edits[p] = std::move(ws);
                  fixed = true;
                  break;
               }
               if (!fixed) return fail("cascade threshold producer not found");
               cascade_fixes++;
            }
         }
         patched_loops++;
         loop_starts.push_back(a);
      }
      if (patched_loops == 0) return fail("no shadow loops");

      uint32_t flag_forced = 0;
      {
         auto cb_words = [&](const Operand& o) { return std::vector<uint32_t>(words.begin() + o.start, words.begin() + o.end); };
         auto writes_comp = [&](const Operand& o, int64_t reg, uint32_t comp) { return o.TempReg() == reg && o.sel == 0 && ((o.swz & 0xF) & (1u << comp)) != 0; };
         auto trace_flag = [&](size_t if_idx) -> std::vector<uint32_t>
         {
            const Operand* o = &insns[if_idx].operands[0];
            size_t from = if_idx;
            for (int hop = 0; hop < 4; hop++)
            {
               if (o->type == OT_CBUFFER) return cb_words(*o);
               int64_t reg = -1; uint32_t comp = 0;
               if (!SrcScalar(*o, reg, comp)) return {};
               const Operand* src = nullptr;
               for (size_t p = from; p-- > 0;)
               {
                  const auto& y = insns[p];
                  if (y.operands.empty() || !writes_comp(y.operands[0], reg, comp)) continue;
                  if (y.op != OP_MOV || y.operands.size() != 2) return {};
                  src = &y.operands[1];
                  from = p;
                  break;
               }
               if (!src) return {};
               o = src;
            }
            return {};
         };
         std::vector<uint32_t> flag_words;
         for (size_t a : loop_starts)
         {
            for (size_t p = a; p-- > 0 && a - p <= 40;)
            {
               const auto& y = insns[p];
               if (y.op == OP_LOOP || y.op == OP_ENDLOOP) break;
               if (y.op != OP_IF || y.operands.size() != 1) continue;
               std::vector<uint32_t> w = trace_flag(p);
               if (!w.empty())
               {
                  if (flag_words.empty()) flag_words = w;
                  else if (flag_words != w) return fail("shadow loops test different flags");
               }
               break;
            }
         }
         if (flag_words.empty())
         {
            for (const auto& x : insns)
            {
               if (x.op != OP_IF && x.op != OP_MOV) continue;
               for (size_t oi = (x.op == OP_MOV ? 1 : 0); oi < x.operands.size(); oi++)
               {
                  const auto& o = x.operands[oi];
                  if (o.type == OT_CBUFFER && o.index_count == 2 && o.indices[0].kind == Index::Imm && o.indices[1].kind == Index::Imm && o.indices[0].value == 2 && o.indices[1].value == 58 && o.sel == 2 && (o.swz & 3) == 1)
                  {
                     flag_words = cb_words(o);
                     break;
                  }
               }
               if (!flag_words.empty()) break;
            }
         }
         if (flag_words.empty()) return fail("shadow filtering flag not found");
         auto is_flag = [&](const Operand& o) { return o.end - o.start == flag_words.size() && std::equal(flag_words.begin(), flag_words.end(), words.begin() + o.start); };
         for (size_t idx = 0; idx < insns.size(); idx++)
         {
            const auto& x = insns[idx];
            if (!((x.op == OP_IF && x.operands.size() == 1 && is_flag(x.operands[0])) || (x.op == OP_MOV && x.operands.size() == 2 && is_flag(x.operands[1])))) continue;
            if (edits.contains(idx)) return fail("shadow filtering flag instruction already edited");
            std::vector<uint32_t> ws;
            const size_t keep = (x.op == OP_MOV) ? x.operands[1].start : x.operands[0].start;
            ws.insert(ws.end(), words.begin() + x.start, words.begin() + keep);
            ws.push_back(0x00004001u);
            ws.push_back(0x3F800000u);
            ws[0] = (ws[0] & ~(0x7Fu << 24)) | (uint32_t(ws.size()) << 24);
            edits[idx] = std::move(ws);
            flag_forced++;
         }
      }

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
         else if (rotation == 3)
         {
            const Operand* pos = nullptr;
            for (size_t k = idx; k-- > 0 && idx - k <= 8;)
            {
               const auto& y = insns[k];
               if (y.op == OP_DP2 && y.operands.size() == 3 && y.operands[2].type == OT_IMM32 && y.operands[2].imm_count == 4 && y.operands[2].imm[0] == IGN_X_BITS && y.operands[0].TempReg() == x.operands[1].TempReg())
               {
                  pos = &y.operands[1];
                  break;
               }
            }
            if (!pos) return fail("gradient noise position not found");
            edits[idx] = MakeNoiseAngle(words, x.operands[0], *pos, sreg);
         }
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
      r.cascade_fixes = cascade_fixes;
      r.flag_forced = flag_forced;
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
      auto result = Patch(words, taps, rotation_mode);
      if (!result)
      {
         failed_shaders++;
         return nullptr;
      }

      const size_t new_size = result->words.size() * 4;
      auto out = std::make_unique<std::byte[]>(new_size);
      std::memcpy(out.get(), result->words.data(), new_size);
      size = new_size;

      if (type == reshade::api::pipeline_subobject_type::compute_shader) patched_compute_shaders++;
      else patched_pixel_shaders++;
      if (result->taps < uint32_t(taps)) patched_shaders_8_taps++;
      {
         const std::unique_lock lock(patched_mutex);
         patched_hashes.insert(uint32_t(shader_hash));
      }
      return out;
   }

   inline std::atomic<uint32_t> noise_frame{ 0 };
   inline std::mutex noise_mutex;
   inline ID3D11Device* noise_device = nullptr;
   inline Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> noise_srvs[ShadowNoise::FRAMES];
   inline Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> const_srvs[std::size(TAP_OPTIONS)];
   inline bool noise_failed = false;

   inline void OnPresent() { noise_frame.fetch_add(1, std::memory_order_relaxed); }

   inline bool EnsureNoise(ID3D11Device* device)
   {
      std::lock_guard lock(noise_mutex);
      if (noise_device == device) return !noise_failed;
      for (auto& srv : noise_srvs) srv.Reset();
      for (auto& srv : const_srvs) srv.Reset();
      noise_device = device;
      noise_failed = false;
      auto give_up = [&]() { for (auto& srv : noise_srvs) srv.Reset(); for (auto& srv : const_srvs) srv.Reset(); noise_failed = true; return false; };
      D3D11_TEXTURE2D_DESC desc = {};
      desc.Width = ShadowNoise::WIDTH;
      desc.Height = ShadowNoise::HEIGHT;
      desc.MipLevels = 1;
      desc.ArraySize = 1;
      desc.Format = DXGI_FORMAT_R8_UNORM;
      desc.SampleDesc.Count = 1;
      desc.Usage = D3D11_USAGE_IMMUTABLE;
      desc.BindFlags = D3D11_BIND_SHADER_RESOURCE;
      for (uint32_t f = 0; f < ShadowNoise::FRAMES; f++)
      {
         D3D11_SUBRESOURCE_DATA init = { ShadowNoise::DATA[f], ShadowNoise::WIDTH, 0 };
         Microsoft::WRL::ComPtr<ID3D11Texture2D> tex;
         if (FAILED(device->CreateTexture2D(&desc, &init, &tex)) || FAILED(device->CreateShaderResourceView(tex.Get(), nullptr, &noise_srvs[f]))) return give_up();
      }
      D3D11_TEXTURE2D_DESC cdesc = desc;
      cdesc.Width = 1;
      cdesc.Height = 1;
      cdesc.Format = DXGI_FORMAT_R32G32B32A32_FLOAT;
      for (size_t i = 0; i < std::size(TAP_OPTIONS); i++)
      {
         const float n = float(TAP_OPTIONS[i]);
         const float values[4] = { n, 1.f / n, 28.f * n / 8.f, std::sqrt(float(KERNEL_TAPS) / n) };
         D3D11_SUBRESOURCE_DATA init = { values, sizeof(values), 0 };
         Microsoft::WRL::ComPtr<ID3D11Texture2D> tex;
         if (FAILED(device->CreateTexture2D(&cdesc, &init, &tex)) || FAILED(device->CreateShaderResourceView(tex.Get(), nullptr, &const_srvs[i]))) return give_up();
      }
      return true;
   }

   inline void BindShadowResources(ID3D11Device* device, ID3D11DeviceContext* context, uint32_t ps_hash, uint32_t cs_hash)
   {
      if (!enabled || device == nullptr || context == nullptr) return;
      const bool cs = cs_hash != 0 && IsPatched(cs_hash);
      const bool ps = !cs && ps_hash != 0 && IsPatched(ps_hash);
      if (!cs && !ps) return;
      if (!EnsureNoise(device)) return;
      size_t option = 0;
      for (size_t i = 0; i < std::size(TAP_OPTIONS); i++) if (TAP_OPTIONS[i] == taps) option = i;
      ID3D11ShaderResourceView* srvs[2] = { const_srvs[option].Get(), noise_srvs[noise_frame.load(std::memory_order_relaxed) % ShadowNoise::FRAMES].Get() };
      if (cs) context->CSSetShaderResources(CONST_SLOT, 2, srvs);
      else context->PSSetShaderResources(CONST_SLOT, 2, srvs);
   }
}
