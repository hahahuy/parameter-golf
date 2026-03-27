#!/usr/bin/env bash
# pod_setup.sh — One-time setup for hahahuy/parameter-golf on a fresh RunPod pod.
# Run once after the pod starts. Safe to re-run (idempotent).
#
# Usage (from /workspace on the pod):
#   bash <(curl -fsSL https://raw.githubusercontent.com/hahahuy/parameter-golf/master/.claude/scripts/pod_setup.sh)
# OR after cloning:
#   bash .claude/scripts/pod_setup.sh [BRANCH]
#
# BRANCH: optional, defaults to master

set -euo pipefail

REPO_URL="https://github.com/hahahuy/parameter-golf.git"
BRANCH="${1:-master}"
WORKSPACE="/workspace"

echo "=== Parameter Golf Pod Setup ==="
echo "Branch: ${BRANCH}"
echo ""

# 1. Install zstandard (missing from the OpenAI template image)
echo "[1/4] Installing zstandard..."
pip install zstandard --quiet
python3 -c "import zstandard; print('  zstandard OK')"

# 2. Clone our fork (skip if already present)
echo "[2/4] Cloning hahahuy/parameter-golf..."
cd "${WORKSPACE}"
if [ ! -d "parameter-golf/.git" ]; then
    git clone "${REPO_URL}"
else
    echo "  Already cloned — skipping"
fi
cd parameter-golf

# 3. Checkout the right branch
echo "[3/4] Checking out branch: ${BRANCH}..."
git fetch origin
git checkout "${BRANCH}"
git pull

# 4. Download FineWeb dataset (10 training shards ~8GB, skips if already present)
echo "[4/4] Downloading FineWeb sp1024 dataset (may take ~10 min first time)..."
python3 data/cached_challenge_fineweb.py --variant sp1024 --train-shards 10

echo ""
echo "=== Setup complete ==="
echo ""
echo "Quick verify:"
echo "  python3 -c \"import zstandard, sentencepiece, torch; from flash_attn_interface import flash_attn_func; print('All deps OK')\""
echo ""
echo "Next — run from repo root:"
echo "  bash .claude/scripts/smoke_test.sh records/track_10min_16mb/FOLDER 1 42"
