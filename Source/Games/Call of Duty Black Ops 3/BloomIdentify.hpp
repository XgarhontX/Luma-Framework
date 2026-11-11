#pragma once

#include <bit>
#include <cstdint>
#include <vector>

#include "ShadowPatch.hpp"

namespace BloomCompute
{
   inline uint32_t DetectBlurXLevel(const uint32_t* words_ptr, size_t count, uint32_t* out_samples = nullptr)
   {
      if (words_ptr == nullptr || count < 4) return 0;
      constexpr uint32_t OP_MUL = 56, OP_SAMPLE = 69, OP_DCL_RESOURCE = 88, OP_DCL_CONSTANT_BUFFER = 89, OP_DCL_SAMPLER = 90, OP_DCL_INPUT_PS = 98;
      std::vector<uint32_t> words(words_ptr, words_ptr + count);
      std::vector<ShadowPatch::Insn> insns;
      if (!ShadowPatch::Parse(words, insns)) return 0;
      uint32_t cbuffers = 0, textures = 0, samplers = 0, constant_inputs = 0, sample_ops = 0;
      for (const auto& x : insns)
      {
         switch (x.op)
         {
         case OP_DCL_CONSTANT_BUFFER: cbuffers++; break;
         case OP_DCL_RESOURCE: textures++; break;
         case OP_DCL_SAMPLER: samplers++; break;
         case OP_DCL_INPUT_PS: if (((words[x.start] >> 11) & 0xF) == 1) constant_inputs++; break;
         case OP_SAMPLE: sample_ops++; break;
         default: break;
         }
      }
      if (cbuffers != 0 || textures != 1 || samplers != 1 || constant_inputs == 0) return 0;
      if (sample_ops < 7 || sample_ops > 15 || (sample_ops % 2) == 0) return 0;
      const uint32_t inv_taps_bits = std::bit_cast<uint32_t>(1.0f / float(sample_ops));
      bool final_mul = false;
      for (const auto& x : insns)
      {
         if (x.op != OP_MUL) continue;
         for (const auto& o : x.operands)
            if (o.type == 4 && o.imm_count == 4 && o.imm[0] == inv_taps_bits && o.imm[1] == inv_taps_bits) final_mul = true;
      }
      if (!final_mul) return 0;
      if (out_samples) *out_samples = sample_ops;
      return (sample_ops - 5) / 2;
   }
}
