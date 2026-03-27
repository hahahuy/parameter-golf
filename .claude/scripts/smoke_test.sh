#!/usr/bin/env bash
# smoke_test.sh — Run a training smoke test and evaluate gate criteria.
#
# Usage:
#   bash .claude/scripts/smoke_test.sh <FOLDER> [NGPU=1] [SEED=42]
#
# FOLDER: path relative to repo root, e.g. records/track_10min_16mb/2026-03-23_P1_Test
# NGPU:   number of GPUs (1 = smoke, 8 = full run)
# SEED:   random seed
#
# Output: structured PASS/FAIL block + appends a row to .claude/experiments.md
# Exit code: 0 = PASS, 1 = FAIL

set -euo pipefail

FOLDER="${1:?Usage: smoke_test.sh <FOLDER> [NGPU=1] [SEED=42]}"
NGPU="${2:-1}"
SEED="${3:-42}"

# Resolve paths
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FOLDER_ABS="${REPO_ROOT}/${FOLDER}"
LOG_FILE="${FOLDER_ABS}/smoke_${NGPU}gpu_seed${SEED}.log"
EXPERIMENTS_MD="${REPO_ROOT}/.claude/experiments.md"

# Gate thresholds differ by GPU count
if [ "$NGPU" -eq 1 ]; then
    THRESH_BPB="1.145"
    THRESH_ART="16000000"
    THRESH_STEP="130"   # ms
    THRESH_WALL="700"   # seconds
    GATE_LABEL="Gate 2 (smoke, 1×H100)"
else
    THRESH_BPB="1.1398"
    THRESH_ART="16000000"
    THRESH_STEP="100"
    THRESH_WALL="600"
    GATE_LABEL="Gate 3 (8×H100 single-seed)"
fi

echo "=== smoke_test.sh ==="
echo "Folder:  ${FOLDER}"
echo "GPUs:    ${NGPU}"
echo "Seed:    ${SEED}"
echo "Gate:    ${GATE_LABEL}"
echo ""

# Verify folder and script exist
if [ ! -f "${FOLDER_ABS}/train_gpt.py" ]; then
    echo "ERROR: ${FOLDER_ABS}/train_gpt.py not found"
    exit 1
fi

# Quick syntax check before spending compute
python3 -c "import ast; ast.parse(open('${FOLDER_ABS}/train_gpt.py').read()); print('Syntax OK')"

# Run training
echo "Running: SEED=${SEED} torchrun --standalone --nproc_per_node=${NGPU} train_gpt.py"
cd "${FOLDER_ABS}"
SEED="${SEED}" torchrun --standalone --nproc_per_node="${NGPU}" train_gpt.py 2>&1 | tee "${LOG_FILE}"
cd "${REPO_ROOT}"

echo ""
echo "=== EXTRACTING METRICS ==="

# Extract metrics (fallback to "N/A" if not found)
VAL_BPB=$(grep -oP "final_int8_zlib_roundtrip val_bpb:\K[0-9.]+" "${LOG_FILE}" | tail -1 || echo "N/A")
PRE_BPB=$(grep -oP "pre_quant_val_bpb:\K[0-9.]+" "${LOG_FILE}" | tail -1 || echo "N/A")
ARTIFACT=$(grep -oP "Total submission size int8\+zlib: \K[0-9]+" "${LOG_FILE}" | tail -1 || echo "N/A")
STEP_MS=$(grep -oP "step_avg[=: ]+\K[0-9.]+" "${LOG_FILE}" | tail -1 || echo "N/A")
WALLCLOCK=$(grep -oP "(total_time|wallclock)[=: ]+\K[0-9.]+" "${LOG_FILE}" | tail -1 || echo "N/A")

# Compute quant gap
if [ "${VAL_BPB}" != "N/A" ] && [ "${PRE_BPB}" != "N/A" ]; then
    QUANT_GAP=$(python3 -c "print(f'{float(\"${PRE_BPB}\") - float(\"${VAL_BPB}\"):.4f}')")
else
    QUANT_GAP="N/A"
fi

# Artifact in MB
if [ "${ARTIFACT}" != "N/A" ]; then
    ARTIFACT_MB=$(python3 -c "print(f'{int(\"${ARTIFACT}\")/1e6:.2f}')")
else
    ARTIFACT_MB="N/A"
fi

# Evaluate each criterion
fail_reason=""

check() {
    local label="$1" value="$2" threshold="$3" op="$4"
    local status
    if [ "$value" = "N/A" ]; then
        status="⚠️ N/A"
    elif python3 -c "exit(0 if float('$value') $op float('$threshold') else 1)" 2>/dev/null; then
        status="PASS"
    else
        status="FAIL"
        [ -z "$fail_reason" ] && fail_reason="${label}=${value} (threshold ${op} ${threshold})"
    fi
    printf "%-12s %-10s [%s]\n" "${label}:" "${value}" "${status}"
}

echo ""
echo "=== SMOKE TEST RESULT ==="
check "val_bpb"   "${VAL_BPB}"   "${THRESH_BPB}" "<="
check "pre_bpb"   "${PRE_BPB}"   "99"            "<="   # informational only
echo "quant_gap:  ${QUANT_GAP}"
check "artifact"  "${ARTIFACT}"  "${THRESH_ART}"  "<="
check "step_ms"   "${STEP_MS}"   "${THRESH_STEP}" "<="
check "wallclock" "${WALLCLOCK}" "${THRESH_WALL}" "<="
echo ""

if [ -z "$fail_reason" ]; then
    echo "VERDICT:    PASS"
    VERDICT="PASS"
else
    echo "VERDICT:    FAIL — ${fail_reason}"
    VERDICT="FAIL"
fi

# Append to experiments.md Our Runs table
DATE_NOW=$(date +%Y-%m-%d)
FOLDER_SHORT=$(basename "${FOLDER}")
NEW_ROW="| ${DATE_NOW} | ${FOLDER_SHORT} | ${NGPU}×H100 seed${SEED} | ${VAL_BPB} | ${VAL_BPB} | ${PRE_BPB} | ${QUANT_GAP} | ${ARTIFACT_MB} | ${NGPU}×H100 | ${VERDICT} |"

# Insert before the "no runs yet" placeholder or append before last line of Our Runs table
if grep -q "_(none yet)_" "${EXPERIMENTS_MD}"; then
    sed -i "s|.*_(none yet)_.*|${NEW_ROW}\n| — | _(none yet)_ | — | — | — | — | — | — | — | — ||" "${EXPERIMENTS_MD}"
else
    # Append after last data row in Our Runs section
    python3 - <<PYEOF
import re, pathlib
p = pathlib.Path("${EXPERIMENTS_MD}")
text = p.read_text()
# Find the Our Runs table and append before its closing blank line
text = re.sub(r'(\| — \| _\(none yet\)_.*\n)', "${NEW_ROW}\n", text) or text
p.write_text(text)
PYEOF
fi

echo ""
echo "Logged to: ${EXPERIMENTS_MD}"

[ "${VERDICT}" = "PASS" ] && exit 0 || exit 1
