# Human Operator Playbook — Parameter Golf

Step-by-step guide for you (not the AI agent) to run this competition.
Three stages: **Local** (CPU, free) → **1×H100 smoke** (~$0.30/run) → **8×H100 final** (~$11/run).

For gate criteria in depth: `.claude/user-guide/decision-gates.md`
For PR creation in depth: `.claude/user-guide/submission-guide.md`
For debugging failures: `.claude/user-guide/bisection-protocol.md`

---

## Where We Are Right Now (2026-03-26)

| Item | Status |
|------|--------|
| Merged SOTA | 1.1194 bpb (`2026-03-23_LeakyReLU_LegalTTT_ParallelMuon`) |
| Open SOTA PR #857 | 1.1048 bpb (15L depth recurrence + TTT 20ep) — not merged yet |
| **Plan D** — Int5 MLP on new base | ✅ Code committed to `experiment/2026-03-26-plan-d-int5-new-base` |
| **Plan B** — 15L depth recurrence | 🔲 Not implemented yet (do after D passes) |
| Target | ≤ 1.109 bpb (beat or match PR #857) |

**Your immediate next step**: smoke test Plan D on 1×H100.

---

## Stage 1 — Pod Setup (do once per pod)

> Full template creation guide: `.claude/user-guide/runpod-template-guide.md`

### 1.1 Launch a pod

**Recommended**: use our custom template (has `zstandard` pre-installed, skips step 1.2).
- Setup guide: `.claude/user-guide/runpod-template-guide.md §Option A`
- GPU: **1× H100 SXM** for smoke, **8× H100 SXM** for Gate 3 / 3-seed

**Fallback**: OpenAI template + manual setup
- Deploy: https://console.runpod.io/deploy?template=y5cejece4j&ref=nl2r56th
- Then run setup script (step 1.2)

```bash
# Connect from your local machine
ssh root@<pod-ip> -p <port> -i ~/.ssh/id_ed25519
```

> Use **Stop** not **Terminate** when done — Terminate wipes the dataset (~8 GB, ~10 min to re-download).

### 1.2 One-time setup (skip if using custom template)

```bash
# On the pod — installs zstandard, clones our fork, downloads dataset
bash <(curl -fsSL https://raw.githubusercontent.com/hahahuy/parameter-golf/master/.claude/scripts/pod_setup.sh)

# To start on a specific branch:
bash <(curl -fsSL https://raw.githubusercontent.com/hahahuy/parameter-golf/master/.claude/scripts/pod_setup.sh) experiment/2026-03-26-pland-int5-newbase
```

### 1.3 Per-run checklist (every pod start)

```bash
cd /workspace/parameter-golf
git pull
ls data/datasets/fineweb10B_sp1024/fineweb_train_*.bin | wc -l  # should be ≥ 10
ln -sf ../../../data records/track_10min_16mb/2026-03-26_PlanD_Int5_NewBase/data
```

---

## Stage 2 — Plan D Smoke Test (1×H100, ~$0.30)

### 2.1 Pull latest code on the pod

```bash
cd /workspace/parameter-golf
git fetch origin
git checkout experiment/2026-03-26-pland-int5-newbase
git pull
```

### 2.2 CPU syntax check (free, catches typos before wasting GPU time)

```bash
python3 -c "
import ast
src = open('records/track_10min_16mb/2026-03-26_PlanD_Int5_NewBase/train_gpt.py').read()
ast.parse(src)
print('Syntax OK')
"
```

If it errors → don't proceed. Fix locally, push, pull again.

### 2.3 Run the smoke test

```bash
# From repo root
bash .claude/scripts/smoke_test.sh records/track_10min_16mb/2026-03-26_PlanD_Int5_NewBase 1 42
```

This runs ~10 min and prints a verdict at the end.

### 2.4 The three numbers to record

```bash
grep "final_int8_zlib_roundtrip val_bpb\|Total submission size\|step_avg" \
  records/track_10min_16mb/2026-03-26_PlanD_Int5_NewBase/smoke_1gpu_seed42.log
```

| # | Metric | Where in log | Pass if |
|---|--------|-------------|---------|
| 1 | **val_bpb** | `final_int8_zlib_roundtrip val_bpb: X.XXXXX` | ≤ 1.122 |
| 2 | **artifact** | `Total submission size int6+lzma: XXXXXXX` | < 15,900,000 bytes |
| 3 | **step_avg** | `step_avg: XXXms` | ≤ 130 ms |

### 2.5 What to do with the numbers

**All three pass** → proceed to Stage 3 (Gate 3 on 8×H100).

**val_bpb > 1.122** → int5 may be hurting quality too much. Tell Claude the exact value.

**artifact ≥ 15,900,000 bytes** → int5 did not save space as expected. Something is wrong — tell Claude.

**step_avg > 130 ms** → unexpected for Plan D (no architecture change). Tell Claude.

**Bigram expansion decision** (only relevant if artifact < 14,500,000 bytes):
```bash
# If artifact < 14.5MB, expand bigram for free ~−0.001 bpb:
# Edit train_gpt.py and change BIGRAM_VOCAB_SIZE default from 2048 to 4096
# Then re-run smoke once more to verify artifact stays < 16MB
```

---

## Stage 3 — Plan D Gate 3: Single 8×H100 seed (~$3.50)

Only run this after Stage 2 passes.

### 3.1 Launch an 8×H100 pod

Same template URL, select **8× H100 SXM**. Same one-time setup as Stage 1.2.

### 3.2 Pull and run

```bash
cd /workspace/parameter-golf
git checkout experiment/2026-03-26-plan-d-int5-new-base && git pull

cd records/track_10min_16mb/2026-03-26_PlanD_Int5_NewBase
SEED=42 torchrun --standalone --nproc_per_node=8 train_gpt.py 2>&1 | tee train_8gpu_seed42.log
```

### 3.3 The three numbers to record

```bash
grep "final_int8_zlib_roundtrip val_bpb\|Total submission size\|step_avg" train_8gpu_seed42.log
```

| # | Pass if |
|---|---------|
| val_bpb | ≤ 1.119 |
| artifact | < 16,000,000 bytes |
| step_avg | ≤ 100 ms |

**Pass** → tell Claude; implement Plan B.
**Fail** → see `.claude/user-guide/bisection-protocol.md`, or tell Claude the exact numbers.

---

## Stage 4 — Implement Plan B (after Plan D Gate 3 passes)

Tell Claude:
```
Plan D Gate 3 passed: val_bpb=X.XXXXX, artifact=XXXXXXX bytes, step_avg=XXXms.
Implement Plan B — 15L depth recurrence.
TASK: implement-and-test
PLAN: B
FOLDER: records/track_10min_16mb/2026-03-26_PlanB_15L_DepthRecurrence
GPU: 1xH100
STOP_AFTER: smoke
```

Claude will implement it. Then repeat Stages 2–3 with the Plan B folder and these gate values:

| Gate 2 (smoke) | Gate 3 (8×H100) |
|----------------|-----------------|
| step_avg **≤ 130 ms** ← hard abort if over | val_bpb ≤ 1.113 |
| val_bpb ≤ 1.120 | step_avg ≤ 100 ms |
| artifact < 16 MB | artifact < 16 MB |

Plan B smoke command:
```bash
bash .claude/scripts/smoke_test.sh records/track_10min_16mb/2026-03-26_PlanB_15L_DepthRecurrence 1 42
```

Plan B Gate 3 command (run from inside folder):
```bash
SEED=42 NUM_LAYERS=15 TIE_LAYERS=9,10,11,12,13 \
  torchrun --standalone --nproc_per_node=8 train_gpt.py 2>&1 | tee train_8gpu_seed42.log
```

> ⚠️ **If step_avg > 130ms on smoke** — stop immediately. Don't proceed to 8×H100. Tell Claude.

---

## Stage 5 — 3-Seed Validation on 8×H100 (~$11)

Only run when Plan B (or Plan D if B fails) passes Gate 3 with val_bpb ≤ 1.113.

```bash
cd records/track_10min_16mb/YYYY-MM-DD_YourFolder/

for SEED in 42 1337 7; do
  SEED=$SEED NUM_LAYERS=15 TIE_LAYERS=9,10,11,12,13 \
    torchrun --standalone --nproc_per_node=8 train_gpt.py 2>&1 | tee train_seed${SEED}.log
done
```

Extract the three numbers (one per seed):
```bash
for f in train_seed42.log train_seed1337.log train_seed7.log; do
  echo -n "$f: "
  grep "final_int8_zlib_roundtrip val_bpb" $f | tail -1
done
```

### Significance test

```bash
S42=$(grep -oP "final_int8_zlib_roundtrip val_bpb:\K[0-9.]+" train_seed42.log | tail -1)
S1337=$(grep -oP "final_int8_zlib_roundtrip val_bpb:\K[0-9.]+" train_seed1337.log | tail -1)
S7=$(grep -oP "final_int8_zlib_roundtrip val_bpb:\K[0-9.]+" train_seed7.log | tail -1)

python3 .claude/scripts/check_significance.py \
  "$S42,$S1337,$S7" \
  "1.11920,1.11940,1.11960"
  # ↑ approximate seeds for merged SOTA (mean=1.1194, std=0.0006)
```

Pass criteria:
- [ ] Mean val_bpb ≤ 1.109
- [ ] p < 0.01
- [ ] All 3 seeds: artifact < 16,000,000 bytes, wallclock < 600s

**Pass** → go to Stage 6 (submit).
**Fail** → tell Claude the exact values; may need more seeds or technique adjustment.

---

## Stage 6 — Submit PR

For full detail: `.claude/user-guide/submission-guide.md`

Quick version:
```bash
# Copy logs back to local machine
scp -P <port> root@<pod-ip>:/workspace/parameter-golf/records/track_10min_16mb/YOUR_FOLDER/train_seed*.log \
  records/track_10min_16mb/YOUR_FOLDER/

# Then tell Claude:
# TASK: submit
# FOLDER: records/track_10min_16mb/YOUR_FOLDER
# Claude will create submission.json, README.md, and open the PR
```

---

## Cost Reference

| Stage | Machine | Time | Cost |
|-------|---------|------|------|
| Syntax check | Local | 5 s | Free |
| Plan D smoke | 1×H100 | ~10 min | ~$0.30 |
| Plan D Gate 3 | 8×H100 | ~10 min | ~$3.50 |
| Plan B smoke | 1×H100 | ~10 min | ~$0.30 |
| Plan B Gate 3 | 8×H100 | ~10 min | ~$3.50 |
| 3-seed validation | 8×H100 | ~35 min | ~$13 |
| **Total (happy path)** | | | **~$21** |

## Key Commands Cheat Sheet

```bash
# Pull new competitor submissions (run daily)
git fetch upstream && git merge upstream/master

# Check for new SOTA
gh pr list --repo openai/parameter-golf --state merged --limit 5

# Smoke test (any folder)
bash .claude/scripts/smoke_test.sh records/track_10min_16mb/FOLDER 1 42

# Gate 3 (any folder, from inside folder)
SEED=42 torchrun --standalone --nproc_per_node=8 train_gpt.py 2>&1 | tee train_8gpu_seed42.log

# Extract the three numbers
grep "final_int8_zlib_roundtrip val_bpb\|Total submission size\|step_avg" train_8gpu_seed42.log

# Significance test
python3 .claude/scripts/check_significance.py "S42,S1337,S7" "SOTA_S42,SOTA_S1337,SOTA_S7"
```
