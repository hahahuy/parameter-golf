# parameter-golf

## Session
- End long sessions with `/handoff` → focused state doc for next session.
- Start new sessions with `/continue` if a handoff doc exists.

<!-- ClaudeVibeCodeKit: commands and planning rules defined in global ~/CLAUDE.md -->

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **parameter-golf** (1304 symbols, 2986 relationships, 89 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> If any GitNexus tool warns the index is stale, run `npx gitnexus analyze` in terminal first.

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `gitnexus_impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `gitnexus_detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `gitnexus_query({query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `gitnexus_context({name: "symbolName"})`.

## When Debugging

1. `gitnexus_query({query: "<error or symptom>"})` — find execution flows related to the issue
2. `gitnexus_context({name: "<suspect function>"})` — see all callers, callees, and process participation
3. `READ gitnexus://repo/parameter-golf/process/{processName}` — trace the full execution flow step by step
4. For regressions: `gitnexus_detect_changes({scope: "compare", base_ref: "main"})` — see what your branch changed

## When Refactoring

- **Renaming**: MUST use `gitnexus_rename({symbol_name: "old", new_name: "new", dry_run: true})` first. Review the preview — graph edits are safe, text_search edits need manual review. Then run with `dry_run: false`.
- **Extracting/Splitting**: MUST run `gitnexus_context({name: "target"})` to see all incoming/outgoing refs, then `gitnexus_impact({target: "target", direction: "upstream"})` to find all external callers before moving code.
- After any refactor: run `gitnexus_detect_changes({scope: "all"})` to verify only expected files changed.

## Never Do

- NEVER edit a function, class, or method without first running `gitnexus_impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `gitnexus_rename` which understands the call graph.
- NEVER commit changes without running `gitnexus_detect_changes()` to check affected scope.

## Tools Quick Reference

| Tool | When to use | Command |
|------|-------------|---------|
| `query` | Find code by concept | `gitnexus_query({query: "auth validation"})` |
| `context` | 360-degree view of one symbol | `gitnexus_context({name: "validateUser"})` |
| `impact` | Blast radius before editing | `gitnexus_impact({target: "X", direction: "upstream"})` |
| `detect_changes` | Pre-commit scope check | `gitnexus_detect_changes({scope: "staged"})` |
| `rename` | Safe multi-file rename | `gitnexus_rename({symbol_name: "old", new_name: "new", dry_run: true})` |
| `cypher` | Custom graph queries | `gitnexus_cypher({query: "MATCH ..."})` |

## Impact Risk Levels

| Depth | Meaning | Action |
|-------|---------|--------|
| d=1 | WILL BREAK — direct callers/importers | MUST update these |
| d=2 | LIKELY AFFECTED — indirect deps | Should test |
| d=3 | MAY NEED TESTING — transitive | Test if critical path |

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/parameter-golf/context` | Codebase overview, check index freshness |
| `gitnexus://repo/parameter-golf/clusters` | All functional areas |
| `gitnexus://repo/parameter-golf/processes` | All execution flows |
| `gitnexus://repo/parameter-golf/process/{name}` | Step-by-step execution trace |

## Self-Check Before Finishing

Before completing any code modification task, verify:
1. `gitnexus_impact` was run for all modified symbols
2. No HIGH/CRITICAL risk warnings were ignored
3. `gitnexus_detect_changes()` confirms changes match expected scope
4. All d=1 (WILL BREAK) dependents were updated

## Keeping the Index Fresh

After committing code changes, the GitNexus index becomes stale. Re-run analyze to update it:

```bash
# ALWAYS use --embeddings — omitting it deletes existing embeddings
npx gitnexus analyze --embeddings
```

To check whether embeddings exist, inspect `.gitnexus/meta.json` — the `stats.embeddings` field shows the count (0 means no embeddings).

> Claude Code users: A PostToolUse hook handles this automatically after `git commit` and `git merge`.

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->

---

## For Spawned Agents

If your prompt contains a task spec with fields `TASK / PLAN / FOLDER / GPU / STOP_AFTER`:
1. Read `.claude/user-guide/agent-testing-workflow.md` — execute it phase by phase
2. Use `.claude/scripts/smoke_test.sh` and `.claude/scripts/check_significance.py` — do not reimplement their logic
3. See `AGENTS.md` (repo root) for the task spec field reference

Do not proceed past `STOP_AFTER` without explicit instruction.

---

## Project Snapshot

**Challenge**: OpenAI Parameter Golf — train the best LM fitting in a 16MB artifact, ≤10 min on 8×H100 SXM, evaluated on FineWeb validation set (bits-per-byte, lower = better).
**Stack**: Python 3.10+, PyTorch, torchrun DDP, SentencePiece sp1024 tokenizer (vocab=1024), zstd-22 compression
**Training entry**: Each submission is a self-contained `train_gpt.py` inside its records folder. Run from within that folder, not the repo root.
**Data**: `data/datasets/fineweb10B_sp1024/` — download via `python3 data/cached_challenge_fineweb.py --variant sp1024`

---

### ⚡ New Agent? Do These First

> Skip nothing. Each step prevents wasted compute.

1. **Read current state** — check `§Active Development State` below. Know what's done and what's next before touching any file.
2. **Check competing PRs** — `gh pr list --repo openai/parameter-golf --state open` — someone may have already beaten the current SOTA since this file was last updated.
3. **Read failures** — `.claude/failures.md` — don't propose a ruled-out technique.
4. **Read experiment log** — `.claude/experiments.md §Our Runs` — don't re-run something already tried.
5. **Follow the gates** — `.claude/user-guide/decision-gates.md` — always smoke-test on 1×H100 before spending $10+ on 3-seed runs.

---

### Active Development State

> **Agent: update this block at the end of every session. Use `/handoff` to preserve full context.**

```
Working copy   : records/track_10min_16mb/2026-04-10_SP8192_PreQuantTTT18ep_AdamW/train_gpt.py
Forked from    : 2026-04-09_SP8192_3LayerRecur_ParResid_QK525_LegalTTT (merged SOTA, 1.0810 bpb)
Plans applied  : Pre-Quant TTT 18ep AdamW (from PR #1482/1517 recipe)
Plans pending  : smoke on 1×H100 → if passes, 3-seed 8×H100
Last 1-seed    : (not run)  val_bpb=—  artifact=—
Last 8×H100    : (not run)  val_bpb=—  artifact=—
Next action    : Smoke test: bash .claude/scripts/smoke_test.sh records/track_10min_16mb/2026-04-10_SP8192_PreQuantTTT18ep_AdamW 1 42
                 Expected: val_bpb ~1.078–1.081, artifact < 16MB
```

---

### Leaderboard Snapshot (2026-04-10)

| Rank | Score (bpb) | Key techniques | Source |
|------|-------------|----------------|--------|
| **Open PR #1517** | **1.0632** | SP8192, 11L/14V depth recur (L3-5), Banked Muon, Pre-Quant TTT 18ep AdamW, brotli | open PR |
| Open PR #1518 | 1.0788 | Wider loop (L3-5×2), per-pass embeddings, Tap-In V6, Legal TTT | open PR |
| Open PR #1514 | 1.0798 | SP8192, Muon momentum=0.97, causal n-gram tilt, Legal TTT | open PR |
| Open PR #1482 | 1.0787 | SP8192, Pre-Quant TTT 8ep (QK=5.25, freeze-1, AdamW lr=0.00045) | open PR |
| **Merged SOTA** | **1.0810** | SP8192, 3L depth recur (L3-5), parallel residuals (L7+), QK-Gain=5.25, Legal TTT | `2026-04-09_SP8192_3LayerRecur_ParResid_QK525_LegalTTT` ← **new copy base** |
| Prev merged | 1.0822 | SP8192, parallel residuals, score-first TTT | `2026-04-08_SP8192_ParallelResid_ScoreFirstTTT` |
| Old base (retired) | 1.1194 | LeakyReLU², TTT, BigramHash, Parallel Muon, sp1024 | `2026-03-23_LeakyReLU_LegalTTT_ParallelMuon` |

**Target**: beat open PR #1517 at **≤1.062 bpb** (p < 0.01, 3 seeds)

### Quick-reference

| Need | File/Location |
|------|--------------|
| Challenge rules | `README.md` |
| Submission how-to | `.claude/user-guide/submission-guide.md` |
| **When to run what (gates)** | `.claude/user-guide/decision-gates.md` |
| **Debugging failed stacks** | `.claude/user-guide/bisection-protocol.md` |
| **All experiment results + technique reference** | `.claude/experiments.md` |
| **Ruled-out / superseded techniques** | `.claude/failures.md` |
| **New copy base (merged SOTA)** | `upstream/main:records/track_10min_16mb/2026-04-09_SP8192_3LayerRecur_ParResid_QK525_LegalTTT/train_gpt.py` |
| Best open PR code (PR #1517, 1.0632 bpb) | `gh pr view 1517 --repo openai/parameter-golf` |

### Artifact Budget

- **Hard cap**: code bytes + compressed model bytes < 16,000,000 bytes (decimal, not MiB)
- Merged SOTA uses ~15.99 MB; PR #1517 uses ~15.0 MB (brotli compressed, 11L/14V)
- Quant scheme (new base): SDClip GPTQ int6 matrices + int8 embeddings + brotli
- PR #1517 quant: SDClip GPTQ int6 + int8 embed + brotli
- Size reported at end: `Total submission size quantized+brotli: XXXXX bytes` — verify < 16000000

---

## Plan Guide — What To Build Next

**New copy base**: `2026-04-09_SP8192_3LayerRecur_ParResid_QK525_LegalTTT` (LZMA-compressed, decode with python3)

Already in merged SOTA base:
- SP8192 tokenizer, GPTQ SDClip int6 matrices + int8 embed, brotli compression
- 3-layer depth recurrence (L3-5, activate at step 35%), 17 virtual layers from 11 physical
- Parallel residuals (L7+), QK-Gain=5.25, Legal score-first TTT (SGD, lr=0.005, 3ep, cosine)
- Muon WD=0.095, EMA=0.9965, warmdown=0.72, MLR=0.022, XSA-all, skip gates, LZMA code wrapper

**What's in open PR #1517 but NOT in merged SOTA** (the gap is −0.018 bpb):
- `RECUR_LAYERS="3,4,5"` with `RECUR_START_STEP=2000` — same layers but different activation mechanism
- **Banked Muon** (parameter banking from PR #399) — parameters shared across recurrence passes
- **Pre-Quant TTT**: AdamW optimizer (not SGD), 18 epochs, lr=0.0003, freeze 1 block, cosine decay
- EMA_DECAY=0.9965, MUON_WD=0.095, WARMDOWN_FRAC=0.72, QK_GAIN_INIT=5.25

**What's in open PR #1518** (−0.0178 bpb vs merged, Tap-In V6 is eval-time only):
- Wider loop: LOOP_START=3, LOOP_END=5, NUM_LOOPS=2 (3 passes through 3 blocks = 9 executions)
- Per-pass loop embeddings: 3 zero-init learned vectors, one per pass
- Tap-In V6 cross-window + bigram-IDF rule (C++ matcher, eval-time only, ~135s)
- Legal Score-First TTT on top

**Strategy options** (ranked by expected Δbpb):
1. **Port Pre-Quant TTT 18ep (AdamW) from PR #1517** onto merged SOTA base — est. −0.012 bpb, Low risk
2. **Port Banked Muon from PR #1517** — est. −0.006 bpb additional, Med risk
3. **Wider loop (L3-5×2) + per-pass embeddings from PR #1518** — est. −0.003 bpb, Med risk
4. **Increase TTT epochs further** (18→30+) — unknown, may overfit

> Plans D and B (int5 MLP, 15L sp1024 depth recurrence) are **retired** — architecture obsoleted by SP8192 stack.

### Commands

> All `torchrun` commands run from inside `records/track_10min_16mb/YYYY-MM-DD_Folder/`.

```bash
# 1×H100 smoke (~$0.30)
bash .claude/scripts/smoke_test.sh records/track_10min_16mb/FOLDER 1 42

# Pre-Quant TTT 18ep (PR #1517 recipe)
TTT_ENABLED=1 TTT_EPOCHS=18 TTT_LR=0.0003 TTT_FREEZE_BLOCKS=1 \
SEED=42 torchrun --standalone --nproc_per_node=1 train_gpt.py

# 8×H100 single seed
SEED=42 torchrun --standalone --nproc_per_node=8 train_gpt.py 2>&1 | tee train_seed42.log

# 3-seed final (8×H100, ~$10.50)
for SEED in 42 1337 314; do
  SEED=$SEED torchrun --standalone --nproc_per_node=8 train_gpt.py 2>&1 | tee train_seed${SEED}.log
done

# Extract results
grep "quantized+brotli\|pre-quantization\|Total submission size\|step_avg\|val_bpb" train_seed42.log
```

## Known Open Items

- [ ] Sync our fork: `git fetch upstream && git merge upstream/main` to pull April merged records
- [ ] Create new working folder forked from `2026-04-09_SP8192_3LayerRecur_ParResid_QK525_LegalTTT`
- [ ] Port Pre-Quant TTT 18ep (AdamW, lr=0.0003, freeze-1 block) from PR #1517 onto merged SOTA
- [ ] Smoke test on 1×H100: confirm step_avg ≤ 130ms, artifact < 16MB
- [ ] If Gate 2 passes (~1.075–1.080 1-seed): run 3-seed 8×H100 confirmation
- [ ] Investigate Banked Muon (PR #1517) — potential additional −0.006 bpb
- [ ] Consider Tap-In V6 eval overlay (PR #1518) — eval-time only, no retraining needed
