#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-default}"
MODE="$(echo "$MODE" | tr '[:lower:]' '[:upper:]')"

echo "======================================"
echo " Microbial Metabarcoding Pipeline"
echo "======================================"
echo "Mode: ${MODE}"
echo ""

echo ">>> Step 1: Read QC"
./02_make_readqc.sh
echo "✓ Read QC completed"
echo ""

echo ">>> Step 2: Running wf-16s"
./03_run_wf16s.sh "${MODE}"
echo "✓ wf-16s completed"
echo ""

echo ">>> Step 3: Mapping QC"
./04_make_mapping_qc.sh
echo "✓ Mapping QC completed"
echo ""

echo ">>> Step 4: Alpha Diversity"
./05_make_alpha_diversity.sh
echo "✓ Alpha diversity completed"
echo ""

echo ">>> Step 5: Combined Report"
./06_make_combined_report.sh
echo "✓ Combined report completed"
echo ""

echo "======================================"
echo " Pipeline finished successfully"
echo "======================================"