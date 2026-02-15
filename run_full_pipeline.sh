#!/bin/bash
# =============================================================================
# run_full_pipeline.sh
# Complete pipeline to generate annotations from GTF
# =============================================================================

set -euo pipefail

# Configuration
WORK_DIR="$(cd "$(dirname "$0")" && pwd)"
INPUT_GTF="${1:-$WORK_DIR/../sqanti3_out/TD2/UTR_annotation/stringtie_long.hq.gtf_corrected.completed.gtf}"
REF_FASTA="${2:-/data/czh/reference_genome/zm4_NG/GCA_048417915.1_ASM4841791v1_modified.fna}"
REF_GTF="${3:-$WORK_DIR/../ZM4.gtf}"
DB_DIR="${4:-$WORK_DIR/reference}"
OUTPUT_DIR="${5:-$WORK_DIR/annotation_results}"

cd "$WORK_DIR"

echo "============================================"
echo "Full Annotation Pipeline"
echo "============================================"
echo "Input GTF: $INPUT_GTF"
echo "Reference GTF: $REF_GTF"
echo "Output Dir: $OUTPUT_DIR"
echo "============================================"

mkdir -p "$OUTPUT_DIR"
mkdir -p "$DB_DIR"

# Step 0: Download databases (if needed)
if [ ! -f "$DB_DIR/uniprot_sprot.dmnd" ]; then
    echo ""
    echo ">>> Step 0: Download Databases"
    bash scripts/00_download_databases.sh "$DB_DIR"
fi

# Step 1: Annotation Pipeline
echo ""
echo ">>> Step 1: Run Annotation Pipeline"
cd "$OUTPUT_DIR"
bash ../scripts/02_annotation_pipeline.sh \
    "$INPUT_GTF" \
    "$REF_FASTA" \
    "$REF_GTF" \
    "$DB_DIR" \
    "." \
    16

# Step 2: Generate Reference Annotations from reference GTF
echo ""
echo ">>> Step 2: Generate Reference Annotations"
cd "$OUTPUT_DIR"
bash ../scripts/03_generate_reference_annotations.sh \
    "$REF_GTF" \
    "reference_transcripts.fa" \
    "" \
    "Reference" \
    16 \
    "$REF_FASTA"

# Step 3: Merge annotations
echo ""
echo ">>> Step 3: Merge Annotations"
cd "$OUTPUT_DIR"
python3 ../scripts/merge_annotations.py \
    --anno_uniprot_besthit anno_uniprot_besthit.tsv \
    --trans_uniprot reference_trans_uniprot.xls \
    --trans_go reference_trans_go.xls \
    --trans_kegg reference_trans_kegg.xls \
    --trans_kog reference_trans_kog.xls \
    --trans_pfam reference_trans_pfam.xls \
    -o merged_annotations.tsv \
    --one_row_per_qseqid

echo ""
echo "============================================"
echo "Pipeline Complete!"
echo "============================================"
echo "Output: $OUTPUT_DIR/merged_annotations.tsv"
ls -lh "$OUTPUT_DIR"
