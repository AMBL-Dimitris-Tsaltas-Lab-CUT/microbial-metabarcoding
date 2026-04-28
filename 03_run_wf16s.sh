#!/usr/bin/env bash
set -euo pipefail

# ------------------------------
# Mode handling
# ------------------------------
MODE="${1:-default}"
MODE="$(echo "$MODE" | tr '[:lower:]' '[:upper:]')"

echo "wf-16s mode: ${MODE}"

case "${MODE}" in
  DEFAULT)
    PARAMS_FILE="01_params_ncbi.yaml"
    ;;
  16S)
    PARAMS_FILE="01_params_silva.yaml"
    ;;
  ITS)
    PARAMS_FILE="01_params_ncbi_its.yaml"
    ;;
  *)
    echo "ERROR: Unknown mode '${MODE}'"
    exit 1
    ;;
esac

echo "Using params file: ${PARAMS_FILE}"

# ------------------------------
# Configuration
# ------------------------------
FASTQ_DIR="data/fastq"
OUTDIR="results/02_wf-16s_${MODE}_$(date +%Y-%m-%d_%H-%M-%S)"
WORKDIR="results/work"
SAMPLE_SHEET="data/fastq/sample_sheet.csv"

# ------------------------------
# Sanity checks
# ------------------------------
if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker not found."
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "ERROR: Docker is not running."
  exit 1
fi

if [ ! -d "$FASTQ_DIR" ]; then
  echo "ERROR: FASTQ_DIR not found: $FASTQ_DIR"
  exit 1
fi

if ! find "$FASTQ_DIR" \( -name "*.fastq" -o -name "*.fastq.gz" -o -name "*.fq" -o -name "*.fq.gz" \) | grep -q .; then
  echo "ERROR: No FASTQ files found under $FASTQ_DIR"
  exit 1
fi

if [ ! -f "$SAMPLE_SHEET" ]; then
  echo "ERROR: sample_sheet.csv not found at $SAMPLE_SHEET"
  exit 1
fi

mkdir -p "$OUTDIR" "$WORKDIR"

# ------------------------------
# Run wf-16s
# ------------------------------
nextflow run epi2me-labs/wf-16s \
  -profile standard \
  -w "$WORKDIR" \
  -params-file "${PARAMS_FILE}" \
  --fastq "$FASTQ_DIR" \
  --sample_sheet "$SAMPLE_SHEET" \
  --out_dir "$OUTDIR" \
  --keep_bam \
  --include_read_assignments \
  --output_unclassified

echo "wf-16s finished. Results in $OUTDIR"