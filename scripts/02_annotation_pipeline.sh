#!/bin/bash
# =============================================================================
# 02_annotation_pipeline.sh
# Main pipeline for transcript annotation
# =============================================================================
# Steps:
#   1. Extract transcript sequences from GTF
#   2. ORF prediction (TransDecoder)
#   3. Diamond比对 (SwissProt + 可选物种数据库)
#   4. Pfam注释
#   5. 整合注释
# =============================================================================

set -euo pipefail

# Configuration
INPUT_GTF="${1:-/path/to/input.gtf}"
REF_FASTA="${2:-/path/to/genome.fa}"
REF_GTF="${3:-/path/to/reference.gtf}"
DB_DIR="${4:-./reference}"
OUTPUT_DIR="${5:-./annotation_results}"
THREADS="${6:-8}"

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "============================================"
echo "Transcriptome Annotation Pipeline"
echo "============================================"
echo "Input GTF: $INPUT_GTF"
echo "Reference Genome: $REF_FASTA"
echo "Output Directory: $OUTPUT_DIR"
echo "============================================"

# Step 1: Extract transcript sequences
echo ""
echo ">>> Step 1: Extract Transcript Sequences"
cd "$OUTPUT_DIR"
if [ ! -f "transcripts.fa" ]; then
    gffread "$INPUT_GTF" -g "$REF_FASTA" -w transcripts.fa
fi
echo "Transcript count: $(grep -c '^>' transcripts.fa)"

# Step 2: ORF prediction
echo ""
echo ">>> Step 2: ORF Prediction (TransDecoder)"
if [ ! -f "transcripts.transdecoder.pep" ]; then
    TransDecoder.LongOrfs -t transcripts.fa -m 100
    TransDecoder.Predict -t transcripts.fa
    mv transcripts.fa.transdecoder.pep transcripts.transdecoder.pep
fi
echo "Protein count: $(grep -c '^>' transcripts.transdecoder.pep)"

# Step 3: Diamond比对 - SwissProt
echo ""
echo ">>> Step 3: Diamond Alignment (SwissProt)"
if [ ! -f "diamond_blastp.outfmt6" ]; then
    diamond blastp \
        --db "$DB_DIR/uniprot_sprot.dmnd" \
        --query transcripts.transdecoder.pep \
        --outfmt 6 \
        --max-target-seqs 1 \
        --evalue 1e-5 \
        --threads "$THREADS" \
        --out diamond_blastp.outfmt6
fi

if [ ! -f "diamond_blastx.outfmt6" ]; then
    diamond blastx \
        --db "$DB_DIR/uniprot_sprot.dmnd" \
        --query transcripts.fa \
        --outfmt 6 \
        --max-target-seqs 1 \
        --evalue 1e-5 \
        --threads "$THREADS" \
        --out diamond_blastx.outfmt6
fi

# Step 4: Pfam注释
echo ""
echo ">>> Step 4: Pfam Domain Annotation"
if [ ! -f "TrinotatePFAM.out" ]; then
    hmmscan --cpu "$THREADS" \
        --domtblout TrinotatePFAM.out \
        "$DB_DIR/Pfam-A.hmm" \
        transcripts.transdecoder.pep > pfam.log
fi

# Step 5: 生成最佳比对结果
echo ""
echo ">>> Step 5: Generate Best Hit Annotations"
python3 << 'EOF'
import pandas as pd
import re

def parse_diamond_to_besthit(diamond_file, output_file, protein_ids):
    """Convert diamond output to besthit format"""
    # Create protein to transcript mapping
    pep_to_trans = {}
    with open(protein_ids) as f:
        for line in f:
            if line.startswith(">"):
                pid = line.strip()[1:].split()[0]
                trans = pid.rsplit('.p', 1)[0]
                pep_to_trans[pid] = trans
    
    # Parse diamond results
    results = {}
    with open(diamond_file) as f:
        for line in f:
            fields = line.strip().split('\t')
            pid = fields[0]
            trans = pep_to_trans.get(pid)
            if trans and trans not in results:
                results[trans] = {
                    'qseqid': pid,
                    'accession': fields[1],
                    'pident': fields[2],
                    'align_len': fields[3],
                    'evalue': fields[10],
                    'bitscore': fields[11]
                }
    
    # Write output
    with open(output_file, 'w') as out:
        out.write('qseqid\taccession\tentry_name\treviewed\tpident\talign_len\tevalue\tbitscore\tdescription\n')
        for trans, data in sorted(results.items()):
            out.write(f"{data['qseqid']}\t{data['accession']}\t.\t.\t{data['pident']}\t{data['align_len']}\t{data['evalue']}\t{data['bitscore']}\t.\n")
    
    return len(results)

# Generate besthit from blastp
parse_diamond_to_besthit('diamond_blastp.outfmt6', 'anno_uniprot_besthit.tsv', 'transcripts.transdecoder.pep')
print("Generated anno_uniprot_besthit.tsv")

EOF

echo ""
echo "============================================"
echo "Annotation Complete!"
echo "============================================"
echo "Output files in: $OUTPUT_DIR"
ls -lh "$OUTPUT_DIR"
