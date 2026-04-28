#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ $# -eq 0 ]; then
  MAPPING_QC_DIR="$(ls -1dt results/03_mapping_qc_* 2>/dev/null | head -n 1 || true)"
  ALPHA_DIV_DIR="$(ls -1dt results/04_alpha_diversity_* 2>/dev/null | head -n 1 || true)"
  WF_RUN_DIR="$(ls -1dt results/02_wf-16s_* 2>/dev/null | head -n 1 || true)"
else
  MAPPING_QC_DIR="$1"
  ALPHA_DIV_DIR="${2:-}"
  WF_RUN_DIR="${3:-}"
fi

MAPPING_QC_FILE="${MAPPING_QC_DIR}/mapping_qc_summary.csv"
ALPHA_DIV_FILE="${ALPHA_DIV_DIR}/alpha_diversity_best3.csv"
ABUNDANCE_FILE="${WF_RUN_DIR}/abundance_table_genus.tsv"

[ -f "${MAPPING_QC_FILE}" ] || { echo "ERROR: Missing ${MAPPING_QC_FILE}"; exit 1; }
[ -f "${ALPHA_DIV_FILE}" ] || { echo "ERROR: Missing ${ALPHA_DIV_FILE}"; exit 1; }
[ -f "${ABUNDANCE_FILE}" ] || { echo "ERROR: Missing ${ABUNDANCE_FILE}"; exit 1; }

command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 not found"; exit 1; }

TIMESTAMP="$(date +"%Y-%m-%d_%H-%M-%S")"
OUTDIR="results/05_combined_report_${TIMESTAMP}"
PER_BARCODE_DIR="${OUTDIR}/genera_over_0_5pct_per_barcode"

mkdir -p "${OUTDIR}" "${PER_BARCODE_DIR}"

OUTPUT_FILE="${OUTDIR}/combined_report.csv"

python3 - "${MAPPING_QC_FILE}" "${ALPHA_DIV_FILE}" "${ABUNDANCE_FILE}" "${OUTPUT_FILE}" "${PER_BARCODE_DIR}" <<'PYTHON_SCRIPT'
import sys
import re
import pandas as pd

mapping_qc_file = sys.argv[1]
alpha_div_file = sys.argv[2]
abundance_file = sys.argv[3]
output_file = sys.argv[4]
per_barcode_dir = sys.argv[5]

THRESHOLD_PERCENT = 0.5

mapping_qc = pd.read_csv(mapping_qc_file)
mapping_qc["sample"] = mapping_qc["sample"].astype(str)
mapping_qc = mapping_qc.rename(columns={"sample": "sample_id"})

alpha_div = pd.read_csv(alpha_div_file)
alpha_div["sample"] = alpha_div["sample"].astype(str)
alpha_div = alpha_div.rename(columns={"sample": "sample_id"})
alpha_div = alpha_div[["sample_id", "richness", "shannon", "inverse_simpson"]]

abundance = pd.read_csv(abundance_file, sep="\t")
taxon_col = abundance.columns[0]

sample_cols = [
    c for c in abundance.columns
    if c != taxon_col and c.lower() != "total"
]

abundance_metrics = []

for sample in sample_cols:
    counts = pd.to_numeric(abundance[sample], errors="coerce").fillna(0)
    total_reads = counts.sum()
    threshold_count = total_reads * (THRESHOLD_PERCENT / 100.0)

    sample_df = abundance[[taxon_col]].copy()
    sample_df["barcode"] = str(sample)
    sample_df["reads"] = counts
    sample_df["percent_of_barcode_reads"] = (
        counts / total_reads * 100 if total_reads > 0 else 0
    )

    sample_df["genus"] = (
        sample_df[taxon_col]
        .astype(str)
        .str.rstrip(";")
        .str.split(";")
        .str[-1]
    )

    filtered = sample_df[
        (sample_df["reads"] > threshold_count) &
        (sample_df["reads"] > 0)
    ].copy()

    filtered = filtered[
        ["barcode", "genus", taxon_col, "reads", "percent_of_barcode_reads"]
    ]

    filtered = filtered.sort_values("reads", ascending=False)

    safe_sample = re.sub(r"[^A-Za-z0-9_.-]+", "_", str(sample))
    out_file = f"{per_barcode_dir}/barcode_{safe_sample}_genera_over_0_5pct.csv"
    filtered.to_csv(out_file, index=False)

    genera_list = filtered["genus"].tolist()

    abundance_metrics.append({
        "sample_id": str(sample),
        "genera_over_0_5pct": "; ".join(genera_list),
        "abundance_threshold_percent": f"{THRESHOLD_PERCENT}%",
        "num_genera_over_0_5pct": len(genera_list),
        "per_barcode_file": out_file
    })

abundance_df = pd.DataFrame(abundance_metrics)

report = mapping_qc.merge(abundance_df, on="sample_id", how="left")
report = report.merge(alpha_div, on="sample_id", how="left")

column_order = [
    "sample_id",
    "mapped_reads",
    "unclassified_reads",
    "total_reads",
    "percent_mapped",
    "percent_unclassified",
    "genera_over_0_5pct",
    "abundance_threshold_percent",
    "num_genera_over_0_5pct",
    "per_barcode_file",
    "richness",
    "shannon",
    "inverse_simpson"
]

report = report[[c for c in column_order if c in report.columns]]
report.to_csv(output_file, index=False)

print(f"OK: Combined report written: {output_file}")
print(f"OK: Per-barcode genus files written to: {per_barcode_dir}")
print(f"Threshold used: > {THRESHOLD_PERCENT}% of total reads per barcode")
PYTHON_SCRIPT

echo ""
echo "DONE."
echo "Combined report: ${OUTPUT_FILE}"
echo "Per-barcode files: ${PER_BARCODE_DIR}"