#!/usr/bin/env bash
set -euo pipefail

# ======================================
# Combined Results Report Generator
# ======================================
# 
# This script combines three result files into a single comprehensive report:
#   1. mapping_qc_summary.csv
#   2. abundance_table_genus.tsv
#   3. alpha_diversity_best3.csv
#
# Usage:
#   ./06_make_combined_report.sh
#   ./06_make_combined_report.sh results/03_mapping_qc_YYYY-MM-DD_HH-MM-SS
#

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Find the most recent result directories if not provided
if [ $# -eq 0 ]; then
  MAPPING_QC_DIR="$(ls -1dt results/03_mapping_qc_* 2>/dev/null | head -n 1 || true)"
  ALPHA_DIV_DIR="$(ls -1dt results/04_alpha_diversity_* 2>/dev/null | head -n 1 || true)"
  WF_RUN_DIR="$(ls -1dt results/02_wf-16s_* 2>/dev/null | head -n 1 || true)"
else
  MAPPING_QC_DIR="$1"
  ALPHA_DIV_DIR="${2:-}"
  WF_RUN_DIR="${3:-}"
fi

# Construct file paths
MAPPING_QC_FILE="${MAPPING_QC_DIR}/mapping_qc_summary.csv"
ALPHA_DIV_FILE="${ALPHA_DIV_DIR}/alpha_diversity_best3.csv"
ABUNDANCE_FILE="${WF_RUN_DIR}/abundance_table_genus.tsv"

# Validation
if [ ! -f "${MAPPING_QC_FILE}" ]; then
  echo "ERROR: mapping_qc_summary.csv not found at ${MAPPING_QC_FILE}"
  exit 1
fi

if [ ! -f "${ALPHA_DIV_FILE}" ]; then
  echo "ERROR: alpha_diversity_best3.csv not found at ${ALPHA_DIV_FILE}"
  exit 1
fi

if [ ! -f "${ABUNDANCE_FILE}" ]; then
  echo "ERROR: abundance_table_genus.tsv not found at ${ABUNDANCE_FILE}"
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 not found. Install Python 3."
  exit 1
fi

# Create output directory
TIMESTAMP="$(date +"%Y-%m-%d_%H-%M-%S")"
OUTDIR="results/05_combined_report_${TIMESTAMP}"
mkdir -p "${OUTDIR}"

OUTPUT_FILE="${OUTDIR}/combined_report.csv"

echo "INFO: Combining results into unified report..."
echo "INFO: Mapping QC:      ${MAPPING_QC_FILE}"
echo "INFO: Alpha Diversity: ${ALPHA_DIV_FILE}"
echo "INFO: Abundance Table: ${ABUNDANCE_FILE}"
echo "INFO: Output:          ${OUTPUT_FILE}"

# Run Python script inline to combine the three files
python3 - "${MAPPING_QC_FILE}" "${ALPHA_DIV_FILE}" "${ABUNDANCE_FILE}" "${OUTPUT_FILE}" <<'PYTHON_SCRIPT'
import sys
import pandas as pd
from pathlib import Path

mapping_qc_file = sys.argv[1]
alpha_div_file = sys.argv[2]
abundance_file = sys.argv[3]
output_file = sys.argv[4]

ABUNDANCE_THRESHOLD_PERCENT = 1.0  # 1% of total counts

try:
    # Load mapping QC summary
    mapping_qc = pd.read_csv(mapping_qc_file)
    mapping_qc['sample'] = mapping_qc['sample'].astype(str)
    mapping_qc = mapping_qc.rename(columns={'sample': 'sample_id'})
    
    # Load alpha diversity metrics
    alpha_div = pd.read_csv(alpha_div_file)
    alpha_div['sample'] = alpha_div['sample'].astype(str)
    alpha_div = alpha_div.rename(columns={'sample': 'sample_id'})
    alpha_div = alpha_div[['sample_id', 'richness', 'shannon', 'inverse_simpson']]
    
    # Load abundance table and extract genera per sample
    abundance = pd.read_csv(abundance_file, sep="\t")
    taxon_col = abundance.columns[0]
    abundance = abundance.set_index(taxon_col)
    abundance = abundance.T
    abundance.index = abundance.index.astype(str)
    
    abundance_metrics = []
    for sample in abundance.index:
        counts = abundance.loc[sample].values
        total_counts = counts.sum()
        
        # Calculate 1% threshold for this sample
        threshold_count = (ABUNDANCE_THRESHOLD_PERCENT / 100.0) * total_counts
        
        # Filter for abundance >= threshold and get genera
        genera_list = []
        for genus_name, count in zip(abundance.columns, counts):
            if count >= threshold_count:
                # Extract the last part after the last semicolon
                last_genus = genus_name.rstrip(';').split(';')[-1]
                genera_list.append(last_genus)
        
        genera_str = "; ".join(genera_list)
        num_genera = len(genera_list)
        
        abundance_metrics.append({
            'sample_id': str(sample),
            'genera_detected': genera_str,
            'abundance_threshold_percent': f"{ABUNDANCE_THRESHOLD_PERCENT}%",
            'num_genera_detected': num_genera
        })
    
    abundance_df = pd.DataFrame(abundance_metrics)
    abundance_df['sample_id'] = abundance_df['sample_id'].astype(str)
    
    # Merge all three dataframes
    report = mapping_qc.merge(abundance_df, on='sample_id', how='left')
    report = report.merge(alpha_div, on='sample_id', how='left')
    
    # Reorder columns for readability
    column_order = [
        'sample_id',
        'mapped_reads',
        'unclassified_reads',
        'total_reads',
        'percent_mapped',
        'percent_unclassified',
        'genera_detected',
        'abundance_threshold_percent',
        'num_genera_detected',
        'richness',
        'shannon',
        'inverse_simpson'
    ]
    report = report[[col for col in column_order if col in report.columns]]
    
    # Write output
    report.to_csv(output_file, index=False)
    
    print(f"OK: Combined report written")
    print(f"  File: {output_file}")
    print(f"  Samples: {len(report)}")
    print(f"  Columns: {len(report.columns)}")
    print(f"  Abundance threshold: {ABUNDANCE_THRESHOLD_PERCENT}% of total counts per sample")
    
except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    import traceback
    traceback.print_exc()
    sys.exit(1)

PYTHON_SCRIPT

if [ ! -f "${OUTPUT_FILE}" ]; then
  echo "ERROR: Failed to create combined report."
  exit 1
fi

echo ""
echo "DONE."
echo "Combined report: ${OUTPUT_FILE}"
