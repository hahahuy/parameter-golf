# Experiment Log

Two tables: **Competitors** (read-only reference) and **Ours** (append every run we do).

---

## Competitors' Runs (read-only reference)

Extracted from `records/*/README.md`. Sorted chronologically ascending.

| Date | Author | Record folder | val_bpb ↓ | Pre-quant bpb | Quant gap | Artifact | Key techniques | Notable findings / negatives |
|------|--------|--------------|:---------:|:-------------:|:---------:|:--------:|----------------|------------------------------|
| 2026-03-17 | Baseline | `2026-03-17_NaiveBaseline` | 1.2244 | 1.2172 | 0.0072 | 15.86MB | 9L×512d, vocab=1024, 4 KV heads, tied emb, MLP×2, int8+zlib | Reference point. 13,780 steps in 600s (43.5ms/step) |
| 2026-03-17 | samacqua | `2026-03-17_LoRA_TTT` | 1.1928 | — | — | 15.86MB | LoRA test-time training on val; doc-isolated + strided eval (stride=256) | Most gain from sliding eval (−0.034) + doc isolation (−0.011), not TTT itself (−0.037 extra) |
| 2026-03-18 | Renier Velazco | `2026-03-18_FP16Embed_WD3600` | 1.2197 | — | ~0.0005 | 15.90MB | FP16 tied embedding, warmdown 1200→3600, MATRIX_LR 0.04→0.06, MLP hidden 1024→992 | FP16 embed reduces quant gap 0.007→0.0005 (32×). ❌ SwiGLU (45% slower), ❌ depth recurrence, ❌ QAT overhead not worth it |
| 2026-03-18 | Spokane Way | `2026-03-18_LongContextSeq2048` | 1.2058 | 1.2005 | 0.0053 | 15.87MB | seq_len 1024→2048, 8×H100 SXM, step=51.9ms | Longer seq costs ~20% more time/step but gains −0.023 nats |
| 2026-03-18 | Will DePue | `non-record: 2026-03-18_Quasi10Bfrom50B` | 1.2074 | 1.1749 | 0.0325 | 15.81MB | Baseline arch, 4h unlimited compute, 172.7B tokens, 329K steps | Shows baseline pre-quant floor ~1.175 with infinite compute. Large quant gap (0.033) without QAT |
| 2026-03-19 | Matthew Li | `2026-03-19_SlidingWindowEval` | 1.1925 | 1.2196 | — | 15.87MB | Sliding window eval stride=64, no training changes | Pure eval trick: −0.032 bpb free. Eval time 16s→70s |
| 2026-03-19 | Nan Liu | `2026-03-19_10L_MixedPrecision` | 1.2147 | 1.2129 | 0.0018 | 15.93MB | 10L, int6 middle layers (3–6), int8 edges, MATRIX_LR=0.02 | Mixed int6/int8 saves 1.6MB vs uniform int8. Near-eliminates quant gap for this arch |
| 2026-03-19 | aquariouseworkman | `2026-03-19_MixedQuant_Int6Int8_SlidingWindow` | 1.1630 | 1.1950 | 0.0015 | 15.35MB | MLP×3 (hidden=1536), int6 blocks + int8 embed, sliding stride=64 | MLP 3× was the biggest single win (−0.029). STE QAT cuts gap to 0.0015 |
| 2026-03-19 | aruniyer | `2026-03-19_MLP3x_QAT_Int6_SlidingWindow` | 1.1502 | ~1.1501 | ~0.0001 | ~15.56MB | STE int6 QAT (all 2D weights), zstd-22, MLP hidden=1344 (2.625×), FP16 embed, Muon momentum=0.99, seq=2048, sliding stride=64 | QAT nearly eliminates quant gap entirely. zstd-22 better than zlib. grad_clip=0.3 |
| 2026-03-19 | Spokane Way | `2026-03-19_TrainingOptSeq4096` | 1.2014 | 1.1980 | 0.0034 | 15.87MB | seq_len 4096, MATRIX_LR=0.02, Muon momentum=0.99 | 4096 ctx −0.015 vs seq2048. Step time=71ms |
| 2026-03-19 | unknown | `2026-03-19_WarmdownQuantization` | 1.2154 | — | — | — | WARMDOWN=20000, MATRIX_LR=0.06, TIED_EMBED_LR=0.07, MUON_BACKEND_STEPS=5, EVAL_SEQ_LEN=1408 | Extended warmdown tightens weight dist → quant gap 0.014→0.005. ❌ WD=30000 overshoots. ❌ MUON_STEPS=7 worse with aggressive warmdown |
| 2026-03-19 | unknown | `non-record: 2026-03-19_SwiGLU_WarmdownFix_1x5090` | 1.3281 | — | — | 15.33MB | SwiGLU, warmdown-as-time-fraction fix, quarter batch (131K), grad accum×2, single RTX 5090 | Hardware-limited. Warmdown fix (fraction not iters) alone −0.006. ❌ Layer recurrence: +0.051 worse (halves steps, gain < step cost) ❌ Weight decay: no benefit at this scale |
| 2026-03-20 | Raahil Shah | `2026-03-20_Int6_MLP3x_SmearGate_BigramHash_MuonWD_SWA` | 1.1458 | 1.1616 | 0.0158 | 15.86MB | int6 all 2D, zstd-22, MLP×3 (1536), SmearGate, BigramHash(4096), OrthoInit, Muon WD=0.04, SWA every 50 steps last 50%, sliding stride=64 | Full stack. Pre-quant 1.1616 − post-quant 1.1458 = 0.016 gap (target for QAT). 7,379 steps in 600s (81ms/step) |
| 2026-03-20 | thwu1 | `2026-03-20_10L_Int5MLP_MuonWD04_SWA50` | **1.1428** | — | — | ~15.9MB | **Int5 MLP** [-16,15] + int6 attn + FP16 embed/last-KV, **10 layers**, **BigramHash(10240)**, SWA frac=0.4 (24 ckpts), WD=0.04, 3% magnitude pruning, sliding stride=64 | **Current SOTA**. Ablations: +10L+int5 −0.003, +SWA(0.4) −0.0006, +bigram(8192) −0.0012, +bigram(10240) −0.0008. σ=0.00016 (very stable) |

---

## Technique Effectiveness Reference

Derived from competitors' ablations. **Check "In #2 base?" before proposing** — the #2 SmearGate script (our copy base) already includes several of these.

| Technique | Proven Δbpb | In #2 base? | Notes |
|-----------|:-----------:|:-----------:|-------|
| Sliding window eval (stride=64) | −0.032 | ✅ yes | Free; pure eval. Already present |
| STE int6 QAT (all 2D weights) | gap 0.016→0.0001 | ✅ yes | Near-eliminates quant penalty. Already in base |
| MLP×3 (hidden=1536) | −0.029 | ✅ yes | Biggest architectural win. Already in base |
| FP16 tied embedding | −0.013 quant gap | ✅ yes | Already in base |
| SmearGate | −0.003 est | ✅ yes | Already in base |
| OrthoInit | ~−0.001 | ✅ yes | Already in base |
| Muon WD=0.04 | ~−0.001 | ✅ yes | Already in base |
| SWA (frac=0.5) | ~−0.002 | ✅ yes (frac=0.5) | Base uses 0.5; tune to 0.4 for +0.0006 |
| BigramHash(4096) | −0.004 est | ✅ yes (4096) | Base has 4096; upgrade to 10240 for +0.002 |
| zstd-22 compression | better than zlib | ✅ yes | Already in base |
| **Int5 MLP** (vs int6) | saves ~1.5MB → funds 10L | ❌ not yet | P1 adds this |
| **10 layers** vs 9 | ~−0.003 | ❌ not yet | P1 adds this (funded by int5 space saving) |
| **BigramHash(10240)** vs 4096 | −0.002 total | ❌ not yet | P2: upgrade from base's 4096 |
| **TrigramHash(8192)** | unknown (novel) | ❌ not yet | P2 adds this; may push artifact > 16MB |
| **QAT int5 + SWA frac=0.4** | quant gap further | ❌ not yet | P4: extend base's int6 QAT to int5 MLP |
| **seq_len 4096** | −0.015 vs 2048 | ❌ not yet | P5 adds this. Slower steps (71ms) |
| SWA frac=0.4 vs 0.5 | −0.0006 | ❌ not yet | P4 tunes this |
| Warmdown fraction schedule | −0.006 | ❌ unknown | Fix warmdown as % wall-clock, not fixed iters |
| Spectral embedding init (Overtone) | unknown Δ | ❌ not yet | Novel, untested vs our stack |
| ❌ SwiGLU | ~−0.004 only | — | 45% slower → fewer steps → net negative |
| ❌ Layer recurrence (fixed time) | +0.051 worse | — | Throughput loss > quality gain. See failures.md |
| ❌ MUON_STEPS=7 + aggressive WD | worse | — | MUON_STEPS=5 better with long warmdown |
| ❌ WARMDOWN_ITERS=30000 | overshoots | — | LR decays too early |

---

## Our Runs

_Append every run here. One row per config. Extract values with:_
`grep "final_int[68].*val_bpb\|DIAGNOSTIC post_ema val_bpb\|Total submission size\|step_avg" train_seed42.log`

| Date | Config | Seeds | val_bpb (each) | Mean | Pre-quant | Gap | MB | GPU | Notes |
|------|--------|:-----:|---------------:|:----:|:---------:|:---:|:--:|:---:|-------|
| — | _(none yet)_ | — | — | — | — | — | — | — | — |
