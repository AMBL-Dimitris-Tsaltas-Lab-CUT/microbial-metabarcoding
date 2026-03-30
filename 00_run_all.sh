#!/usr/bin/env bash
set -euo pipefail

echo "======================================"
echo " Microbial Metabarcoding Pipeline"
echo "======================================"
echo ""

# ------------------------------
# Step 1 – Read QC
# ------------------------------
echo ">>> Step 1: Read QC"
./02_make_readqc.sh
echo "✓ Read QC completed"
echo ""

# ------------------------------
# Step 2 – wf-16s Classification
# ------------------------------
echo ">>> Step 2: Running wf-16s"
./03_run_wf16s.sh
echo "✓ wf-16s completed"
echo ""

# ------------------------------
# Step 3 – Mapping QC
# ------------------------------
echo ">>> Step 3: Mapping QC"
./04_make_mapping_qc.sh
echo "✓ Mapping QC completed"
echo ""

# ------------------------------
# Step 4 – Alpha Diversity
# ------------------------------
echo ">>> Step 4: Alpha Diversity"
./05_make_alpha_diversity.sh
echo "✓ Alpha diversity completed"
echo ""

echo "======================================"
echo " Pipeline finished successfully"
echo "======================================"

