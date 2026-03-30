#!/usr/bin/env bash
set -euo pipefail

# ------------------------------
# Usage:
#   ./04_make_mapping_qc.sh
#   ./04_make_mapping_qc.sh results/02_wf-16s_YYYY-MM-DD_HH-MM-SS
# ------------------------------

WF_RUN_DIR="${1:-}"

if [ -z "${WF_RUN_DIR}" ]; then
  WF_RUN_DIR="$(ls -1dt results/02_wf-16s_* 2>/dev/null | head -n 1 || true)"
fi

if [ -z "${WF_RUN_DIR}" ] || [ ! -d "${WF_RUN_DIR}" ]; then
  echo "ERROR: Could not find wf-16s results directory."
  echo "Expected something like: results/02_wf-16s_YYYY-MM-DD_HH-MM-SS"
  echo "Or pass it explicitly:"
  echo "  ./04_make_mapping_qc.sh results/02_wf-16s_YYYY-MM-DD_HH-MM-SS"
  exit 1
fi

BAMSTATS_DIR="${WF_RUN_DIR}/bams"
UNCLASS_DIR="${WF_RUN_DIR}/unclassified"

if [ ! -d "${BAMSTATS_DIR}" ]; then
  echo "ERROR: Missing bams directory: ${BAMSTATS_DIR}"
  exit 1
fi

TIMESTAMP="$(date +"%Y-%m-%d_%H-%M-%S")"
OUTDIR="results/03_mapping_qc_${TIMESTAMP}"
OUTFILE="${OUTDIR}/mapping_qc_summary.csv"
mkdir -p "${OUTDIR}"

echo "sample,mapped_reads,unclassified_reads,total_reads,percent_mapped,percent_unclassified" > "${OUTFILE}"

for dir in "${BAMSTATS_DIR}"/*.bamstats_results; do
  sample="$(basename "$dir" .bamstats_results)"

  readstats="${dir}/bamstats.readstats.tsv.gz"
  unclassified_fastq="${UNCLASS_DIR}/${sample}.unclassified.fq.gz"

  if [ ! -f "${readstats}" ]; then
    echo "ERROR: Missing readstats file: ${readstats}"
    exit 1
  fi

  mapped="$(gunzip -c "${readstats}" | tail -n +2 | wc -l | awk '{print $1}')"

  if [ -f "${unclassified_fastq}" ]; then
    unclassified_reads="$(gunzip -c "${unclassified_fastq}" | wc -l | awk '{print int($1/4)}')"
  else
    unclassified_reads=0
  fi

  total=$((mapped + unclassified_reads))

  if [ "${total}" -gt 0 ]; then
    percent_mapped="$(awk -v m="${mapped}" -v t="${total}" 'BEGIN {printf "%.2f", (m/t)*100}')"
    percent_unclassified="$(awk -v u="${unclassified_reads}" -v t="${total}" 'BEGIN {printf "%.2f", (u/t)*100}')"
  else
    percent_mapped="0.00"
    percent_unclassified="0.00"
  fi

  echo "${sample},${mapped},${unclassified_reads},${total},${percent_mapped},${percent_unclassified}" >> "${OUTFILE}"
done

echo "Mapping QC summary written to:"
echo "  ${OUTFILE}"
echo "Using wf-16s run folder:"
echo "  ${WF_RUN_DIR}"



