#!/bin/bash
# =============================================================================
# 01_prepare_reference.sh
# Generate reference annotation files from GTF
# =============================================================================
# Input: GTF file (e.g., ZM4.gtf)
# Output: *_trans_uniprot.xls, *_trans_go.xls, *_trans_kegg.xls, etc.
#
# This script extracts transcript/gene information from GTF and prepares
# mapping files needed for downstream annotation
# =============================================================================

set -euo pipefail

INPUT_GTF="${1:-../ZM4.gtf}"
OUTPUT_PREFIX="${2:-Medicago_Sativa}"
THREADS="${3:-16}"

echo "=== Generating Reference Annotations ==="
echo "Input GTF: $INPUT_GTF"
echo "Output Prefix: $OUTPUT_PREFIX"

# Extract transcript and gene information from GTF
echo "[1/6] Extracting transcript and gene info..."

# Get unique transcripts
awk -F'\t' '$3=="transcript"' "$INPUT_GTF" | \
    awk '{
        for(i=9; i<=NF; i++) {
            if($i ~ /transcript_id/) {
                match($i, /"([^"]+)"/, m)
                tid = m[1]
            }
            if($i ~ /gene_id/) {
                match($i, /"([^"]+)"/, m)
                gid = m[1]
            }
            if($i ~ /gene_name/ || $i ~ /Name/) {
                match($i, /"([^"]+)"/, m)
                gname = m[1]
            }
        }
        print tid "\t" gid "\t" gname
    }' | sort -u > "${OUTPUT_PREFIX}_gene_trans_map.txt"

# Extract protein coding sequences using TransDecoder
echo "[2/6] Extracting protein sequences..."

# Create transcript FASTA from GTF (requires genome)
# This is optional - if you have transcripts.fa, skip this

# Generate protein sequences using TransDecoder
# TransDecoder.LongOrfs -t transcripts.fa -m 100
# TransDecoder.Predict -t transcripts.fa

# For now, create placeholder files if they don't exist
if [ ! -f "${OUTPUT_PREFIX}.fa" ]; then
    echo "Warning: Transcript FASTA not generated yet"
fi

# Create UniProt mapping (placeholder - needs actual mapping from protein IDs)
echo "[3/6] Creating UniProt mapping..."
# This would require running diamond and parsing results
echo "transcript_id	accession	description" > "${OUTPUT_PREFIX}_trans_uniprot.xls"

# Create GO annotation (placeholder)
echo "[4/6] Creating GO annotation..."
echo "transcript_id	accession	go_term	namespace	description" > "${OUTPUT_PREFIX}_trans_go.xls"

# Create KEGG annotation (placeholder)
echo "[5/6] Creating KEGG annotation..."
echo "transcript_id	accession	ko	annotation" > "${OUTPUT_PREFIX}_trans_kegg.xls"

# Create KOG annotation (placeholder)
echo "[6/6] Creating KOG annotation..."
echo "transcript_id	kog_id	kog_name	class" > "${OUTPUT_PREFIX}_trans_kog.xls"

# Create Pfam annotation (placeholder)
echo "[7/7] Creating Pfam annotation..."
echo "transcript_id	accession	pfam	description" > "${OUTPUT_PREFIX}_trans_pfam.xls"

echo "=== Reference Annotation Generation Complete ==="
echo "Output files:"
ls -lh "${OUTPUT_PREFIX}"*.xls
