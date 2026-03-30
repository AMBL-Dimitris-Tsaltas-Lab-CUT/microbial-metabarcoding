#!/usr/bin/env bash
set -euo pipefail

# ------------------------------
# Configuration
# ------------------------------
FASTQ_DIR="data/fastq"
OUTDIR="results/02_wf-16s_$(date +%Y-%m-%d_%H-%M-%S)"
WORKDIR="results/work"
SAMPLE_SHEET="data/fastq/sample_sheet.csv"

# ------------------------------
# Sanity checks
# ------------------------------
if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker not found. Install Docker Desktop and start it."
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
  -params-file 01_params.yaml \
  --fastq "$FASTQ_DIR" \
  --sample_sheet "$SAMPLE_SHEET" \
  --out_dir "$OUTDIR" \
  --keep_bam \
  --include_read_assignments \
  --output_unclassified \
  "$@"

echo "wf-16s finished. Results in $OUTDIR"
