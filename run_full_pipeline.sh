#!/bin/bash
# =============================================================================
# run_full_pipeline.sh
# Complete pipeline to generate annotations from GTF
# =============================================================================

set -euo pipefail

# Configuration
WORK_DIR="${1:-./annotation_results}"
INPUT_GTF="${2:-/path/to/input.gtf}"
REF_FASTA="${3:-/path/to/genome.fa}"
REF_GTF="${4:-/path/to/reference.gtf}"
DB_DIR="${5:-./reference}"

cd "$(dirname "$0")"

echo "============================================"
echo "Full Annotation Pipeline"
echo "============================================"

# Step 0: Download databases
echo ""
echo ">>> Step 0: Download Databases"
mkdir -p "$DB_DIR"
bash scripts/00_download_databases.sh "$DB_DIR"

# Step 1: Prepare reference (if needed)
# bash scripts/01_prepare_reference.sh "$REF_GTF" "Medicago_Sativa"

# Step 2: Run annotation pipeline
echo ""
echo ">>> Step 2: Run Annotation"
mkdir -p annotation_results
cd annotation_results
bash ../scripts/02_annotation_pipeline.sh "$INPUT_GTF" "$REF_FASTA" "$REF_GTF" "$DB_DIR" "." 16

# Step 3: Merge annotations
# Note: Requires reference annotation files (*_trans_*.xls)
# bash scripts/merge_annotations.py \
#     --anno_uniprot_besthit anno_uniprot_besthit.tsv \
#     --trans_uniprot ../reference/Medicago_Sativa_trans_uniprot.xls \
#     --trans_go ../reference/Medicago_Sativa_trans_go.xls \
#     --trans_kegg ../reference/Medicago_Sativa_trans_kegg.xls \
#     --trans_kog ../reference/Medicago_Sativa_trans_kog.xls \
#     --trans_pfam ../reference/Medicago_Sativa_trans_pfam.xls \
#     -o merged_annotations.tsv \
#     --one_row_per_qseqid

echo ""
echo "============================================"
echo "Pipeline Complete!"
echo "============================================"
