#!/usr/bin/env bash
set -euo pipefail

# ------------------------------
# Usage
#   ./05_make_alpha_diversity.sh
#   ./05_make_alpha_diversity.sh results/02_wf-16s_*/abundance_table_genus.tsv
# ------------------------------

ABUND_TABLE="${1:-}"

if [ -z "${ABUND_TABLE}" ]; then
  latest_run="$(ls -1dt results/02_wf-16s_* 2>/dev/null | head -n 1 || true)"
  if [ -z "${latest_run}" ]; then
    echo "ERROR: Could not find results/02_wf-16s_* folder."
    echo "Pass the abundance table explicitly:"
    echo "  ./05_make_alpha_diversity.sh results/02_wf-16s_*/abundance_table_genus.tsv"
    exit 1
  fi
  ABUND_TABLE="${latest_run}/abundance_table_genus.tsv"
fi

if [ ! -f "${ABUND_TABLE}" ]; then
  echo "ERROR: Abundance table not found: ${ABUND_TABLE}"
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 not found. Install Python 3."
  exit 1
fi

TIMESTAMP="$(date +"%Y-%m-%d_%H-%M-%S")"
OUTDIR="results/04_alpha_diversity_${TIMESTAMP}"
OUTCSV="${OUTDIR}/alpha_diversity_best3.csv"

mkdir -p "${OUTDIR}"

python3 - <<'PY' "${ABUND_TABLE}" "${OUTCSV}"
import math
import sys
import pandas as pd

abund_path = sys.argv[1]
out_csv = sys.argv[2]

df = pd.read_csv(abund_path, sep="\t")
if df.shape[1] < 2:
    raise SystemExit("ERROR: abundance table has <2 columns. Expected taxon + >=1 sample columns.")

taxon_col = df.columns[0]
df = df.set_index(taxon_col)

for c in df.columns:
    df[c] = pd.to_numeric(df[c], errors="coerce").fillna(0)

rows = []
for sample in df.columns:
    counts = df[sample].values
    counts = counts[counts > 0]

    N = float(counts.sum()) if counts.size else 0.0
    S = int(counts.size)

    if N <= 0 or S <= 0:
        shannon = 0.0
        inv_simpson = 0.0
    else:
        p = counts / N
        # Shannon (natural log)
        shannon = float(-(p * (pd.Series(p).apply(lambda x: math.log(x))).values).sum())
        # Simpson D = sum(p^2); Inverse Simpson = 1/D
        D = float((p * p).sum())
        inv_simpson = float(1.0 / D) if D > 0 else 0.0

    rows.append({
        "sample": sample,
        "richness": S,
        "shannon": round(shannon, 4),
        "inverse_simpson": round(inv_simpson, 4),
        "total_counts": int(round(N, 0)),
    })

out = pd.DataFrame(rows)[["sample", "richness", "shannon", "inverse_simpson", "total_counts"]]
out.to_csv(out_csv, index=False)
print(f"Wrote: {out_csv}")
PY

echo "Alpha diversity (best 3 + total_counts) written to:"
echo "  ${OUTCSV}"
echo ""
echo "Source abundance table:"
echo "  ${ABUND_TABLE}"

