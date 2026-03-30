#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

FASTQ_ROOT="${SCRIPT_DIR}/data/fastq"
OUTDIR="${SCRIPT_DIR}/results/01_reads_qc_$(date +%Y-%m-%d_%H-%M-%S)"
THREADS="${THREADS:-8}"
NANOPLOT_MAXREADS="${NANOPLOT_MAXREADS:-0}"   # 0 = all reads

command -v NanoPlot >/dev/null 2>&1 || { echo "ERROR: NanoPlot not found in PATH"; exit 1; }
command -v gzip >/dev/null 2>&1 || { echo "ERROR: gzip not found in PATH"; exit 1; }

mkdir -p "${OUTDIR}/nanoplot" "${OUTDIR}/logs" "${OUTDIR}/tmp"

INDEX_CSV="${OUTDIR}/qc_index.csv"
echo "barcode,fastq_dir,nanoplot_dir,html_report,status" > "${INDEX_CSV}"

echo "INFO: Running NanoPlot QC..."
echo "INFO: FASTQ_ROOT=${FASTQ_ROOT}"
echo "INFO: OUTDIR=${OUTDIR}"

for bc_dir in "${FASTQ_ROOT}"/barcode*; do
  [ -d "${bc_dir}" ] || continue

  barcode="$(basename "${bc_dir}")"
  np_out="${OUTDIR}/nanoplot/${barcode}"
  mkdir -p "${np_out}"

  list_file="${OUTDIR}/logs/${barcode}.fastq_files.txt"
  : > "${list_file}"

  # Robust file discovery (handles spaces)
  find "${bc_dir}" -maxdepth 1 -type f \( -name "*.fastq" -o -name "*.fastq.gz" -o -name "*.fq" -o -name "*.fq.gz" \) -print0 \
    | while IFS= read -r -d '' f; do
        printf "%s\n" "$f" >> "${list_file}"
      done

  if [ ! -s "${list_file}" ]; then
    echo "WARN: No FASTQ files in ${bc_dir}, skipping."
    echo "${barcode},${bc_dir},${np_out},,NO_FASTQ" >> "${INDEX_CSV}"
    continue
  fi

  # Create a real temporary FASTQ file for NanoPlot
  tmp_fastq="${OUTDIR}/tmp/${barcode}.merged.fastq"
  rm -f "${tmp_fastq}"

  echo "INFO: Building temp FASTQ for ${barcode} -> ${tmp_fastq}"

  while IFS= read -r f; do
    f="$(printf "%s" "$f" | tr -d '\r')"
    case "$f" in
      *.gz) gzip -dc -- "$f" >> "${tmp_fastq}" ;;
      *)    cat -- "$f" >> "${tmp_fastq}" ;;
    esac
  done < "${list_file}"

  if [ ! -s "${tmp_fastq}" ]; then
    echo "ERROR: Temp FASTQ is empty for ${barcode}."
    echo "${barcode},${bc_dir},${np_out},,EMPTY_TEMP_FASTQ" >> "${INDEX_CSV}"
    exit 1
  fi

  max_reads_arg=""
  if [ "${NANOPLOT_MAXREADS}" -gt 0 ]; then
    max_reads_arg="--max_reads ${NANOPLOT_MAXREADS}"
  fi

  NP_LOG="${OUTDIR}/logs/${barcode}.nanoplot.log"

  set +e
  NanoPlot \
    --fastq "${tmp_fastq}" \
    --outdir "${np_out}" \
    --threads "${THREADS}" \
    --loglength \
    --plots hex dot \
    ${max_reads_arg} \
    > "${NP_LOG}" 2>&1
  NP_EXIT=$?
  set -e

  # Remove temp FASTQ to save space (comment this out if you want to keep it)
  rm -f "${tmp_fastq}"

  html="${np_out}/NanoPlot-report.html"

  if [ "${NP_EXIT}" -ne 0 ] || [ ! -f "${html}" ]; then
    echo "ERROR: NanoPlot failed for ${barcode}."
    echo "  Exit code: ${NP_EXIT}"
    echo "  Log: ${NP_LOG}"
    echo "  File list: ${list_file}"
    echo "${barcode},${bc_dir},${np_out},${html},FAILED" >> "${INDEX_CSV}"
    tail -n 30 "${NP_LOG}" || true
    exit 1
  fi

  echo "OK: ${barcode} -> ${html}"
  echo "${barcode},${bc_dir},${np_out},${html},OK" >> "${INDEX_CSV}"
done

echo "DONE."
echo "Index: ${INDEX_CSV}"
echo "Reports: ${OUTDIR}/nanoplot/*/NanoPlot-report.html"
