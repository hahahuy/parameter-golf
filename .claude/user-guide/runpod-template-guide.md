# RunPod Custom Template Guide

How to create your own RunPod template based on the OpenAI parameter-golf image,
with `zstandard` pre-installed and pointing to your fork.

---

## Option A — Custom Template (recommended, reusable)

Creates a persistent template you can deploy with one click for any future pod.

### Steps

1. Go to **https://www.runpod.io/console/user/templates**
2. Click **+ New Template**
3. Fill in the fields:

| Field | Value |
|-------|-------|
| **Template Name** | `Parameter Golf — hahahuy` |
| **Container Image** | `runpod/parameter-golf:latest` |
| **Container Disk** | `50 GB` |
| **Volume Disk** | `50 GB` |
| **Volume Mount Path** | `/workspace` |
| **Expose TCP Ports** | `22` |
| **Expose HTTP Ports** | `8888` |
| **Container Start Command** | `bash -c "pip install -q zstandard && /start.sh"` |

4. Click **Save Template**

The start command installs `zstandard` before the normal RunPod entrypoint (`/start.sh`) launches SSH and Jupyter, so it's ready by the time you SSH in.

### Deploy a pod from your template

1. Go to **https://www.runpod.io/console/deploy**
2. Choose GPU: **1× H100 SXM** (smoke) or **8× H100 SXM** (Gate 3 / 3-seed)
3. Click **Change Template** → find `Parameter Golf — hahahuy`
4. Deploy

---

## Option B — Manual setup per pod (no template creation needed)

Use the OpenAI template as-is and run the setup script once after the pod starts.

### On a fresh pod

```bash
# SSH into the pod, then:
bash <(curl -fsSL https://raw.githubusercontent.com/hahahuy/parameter-golf/master/.claude/scripts/pod_setup.sh)
```

This does everything in one shot:
- installs `zstandard`
- clones `hahahuy/parameter-golf` to `/workspace/parameter-golf`
- checks out `master` (pass a branch name as arg to override)
- downloads the FineWeb sp1024 dataset (~8 GB, ~10 min)

To check out a specific experiment branch:
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/hahahuy/parameter-golf/master/.claude/scripts/pod_setup.sh) experiment/2026-03-26-pland-int5-newbase
```

### After setup (both options)

```bash
cd /workspace/parameter-golf

# Create data symlink in experiment folder (needed before every run)
ln -sf ../../../data records/track_10min_16mb/2026-03-26_PlanD_Int5_NewBase/data

# Smoke test
bash .claude/scripts/smoke_test.sh records/track_10min_16mb/2026-03-26_PlanD_Int5_NewBase 1 42

# Gate 3 (8×H100 pod only)
cd records/track_10min_16mb/2026-03-26_PlanD_Int5_NewBase
SEED=42 torchrun --standalone --nproc_per_node=8 train_gpt.py 2>&1 | tee train_8gpu_seed42.log
```

---

## Keeping the Dataset Across Restarts

RunPod volumes persist between **Stop/Start** but are wiped on **Terminate**.

- Dataset lives at `/workspace/parameter-golf/data/datasets/fineweb10B_sp1024/`
- If you accidentally Terminate: re-run `pod_setup.sh` — it re-downloads the dataset
- `--train-shards 10` downloads 10 shards (~8 GB). For full training you only need 10.

---

## Quick Reference — Per-pod Checklist

Every time you start a pod (whether using Option A or B):

```bash
# 1. Verify deps
python3 -c "import zstandard, sentencepiece, torch; from flash_attn_interface import flash_attn_func; print('All deps OK')"

# 2. Pull latest code
cd /workspace/parameter-golf && git pull

# 3. Check data exists
ls data/datasets/fineweb10B_sp1024/fineweb_train_*.bin | wc -l  # should be ≥ 10

# 4. Create data symlink for your experiment folder
ln -sf ../../../data records/track_10min_16mb/YOUR_FOLDER/data
```
