#!/bin/bash
# =============================================================================
# generate_reference_annotations.sh
# Generate reference annotation files from GTF
# =============================================================================
# This script generates the required reference annotation files:
# - *_trans_uniprot.xls: Transcript to UniProt mapping
# - *_trans_go.xls: GO annotations
# - *_trans_kegg.xls: KEGG pathway annotations
# - *_trans_kog.xls: KOG ortholog annotations
# - *_trans_pfam.xls: Pfam domain annotations
# =============================================================================

set -euo pipefail

INPUT_GTF="${1:-../ZM4.gtf}"
TRANSCRIPTS="${2:-transcripts.fa}"
REF_PEP="${3:-reference_proteins.fa}"
OUTPUT_PREFIX="${4:-Reference}"
THREADS="${5:-16}"

echo "=== Generating Reference Annotations ==="
echo "Input GTF: $INPUT_GTF"
echo "Output Prefix: $OUTPUT_PREFIX"

mkdir -p tmp

# Step 1: Extract transcripts from GTF if needed
if [ ! -f "$TRANSCRIPTS" ]; then
    echo "[1/8] Extracting transcript sequences..."
    GENOME_FASTA="${6:-/data/czh/reference_genome/zm4_NG/GCA_048417915.1_ASM4841791v1_modified.fna}"
    gffread "$INPUT_GTF" -g "$GENOME_FASTA" -w "$TRANSCRIPTS"
fi

# Step 2: ORF prediction
echo "[2/8] ORF prediction..."
if [ ! -f "${TRANSCRIPTS}.transdecoder.pep" ]; then
    TransDecoder.LongOrfs -t "$TRANSCRIPTS" -m 100
    TransDecoder.Predict -t "$TRANSCRIPTS"
    mv "${TRANSCRIPTS}.transdecoder.pep" "${TRANSCRIPTS}.transdecoder.pep"
fi

# Step 3: Diamond比对
echo "[3/8] Diamond alignment..."
if [ ! -f "diamond_ref_blastp.outfmt6" ]; then
    diamond blastp \
        --db uniprot_sprot.dmnd \
        --query "${TRANSCRIPTS}.transdecoder.pep" \
        --outfmt 6 \
        --max-target-seqs 1 \
        --evalue 1e-5 \
        --threads "$THREADS" \
        --out diamond_ref_blastp.outfmt6
fi

# Step 4: Generate trans_uniprot.xls
echo "[4/8] Generating trans_uniprot.xls..."
python3 << 'PYEOF'
import sys

# Read diamond results
acc_to_qid = {}
with open("diamond_ref_blastp.outfmt6") as f:
    for line in f:
        fields = line.strip().split("\t")
        qid = fields[0]
        sid = fields[1]
        if qid not in acc_to_qid:
            acc_to_qid[qid] = sid

# Read protein IDs
pep_to_trans = {}
with open(sys.argv[1]) as f:
    for line in f:
        if line.startswith(">"):
            pid = line.strip()[1:].split()[0]
            trans = pid.rsplit('.p', 1)[0]
            pep_to_trans[pid] = trans

# Write output
with open("reference_trans_uniprot.xls", "w") as out:
    out.write("SeqID\tAccession\tAnnotation\n")
    for pid, sid in acc_to_qid.items():
        trans = pep_to_trans.get(pid, pid)
        out.write(f"{trans}\t{sid}\t\n")

print("Done: reference_trans_uniprot.xls")
PYEOF
${TRANSCRIPTS}.transdecoder.pep

# Step 5: Pfam注释
echo "[5/8] Pfam annotation..."
if [ ! -f "reference_pfam.out" ]; then
    hmmscan --cpu "$THREADS" \
        --domtblout reference_pfam.out \
        Pfam-A.hmm \
        "${TRANSCRIPTS}.transdecoder.pep" > pfam_ref.log
fi

# Step 6: Generate trans_pfam.xls
echo "[6/8] Generating trans_pfam.xls..."
python3 << 'PYEOF'
import sys

# Read protein IDs
pep_to_trans = {}
with open(sys.argv[1]) as f:
    for line in f:
        if line.startswith(">"):
            pid = line.strip()[1:].split()[0]
            trans = pid.rsplit('.p', 1)[0]
            pep_to_trans[pid] = trans

# Read Pfam results
pfam_data = {}
with open("reference_pfam.out") as f:
    for line in f:
        if line.startswith("#") or not line.strip():
            continue
        fields = line.strip().split()
        if len(fields) < 4:
            continue
        pid = fields[3]
        pfam_id = fields[1]
        desc = fields[22] if len(fields) > 22 else ""
        
        trans = pep_to_trans.get(pid)
        if trans and trans not in pfam_data:
            pfam_data[trans] = (pfam_id, desc)

# Write output
with open("reference_trans_pfam.xls", "w") as out:
    out.write("SeqID\tAccession\tHMMProfile\tDescription\n")
    for trans, (pfam_id, desc) in sorted(pfam_data.items()):
        out.write(f"{trans}\t.\t{pfam_id}\t{desc}\n")

print("Done: reference_trans_pfam.xls")
PYEOF
${TRANSCRIPTS}.transdecoder.pep

# Step 7: eggNOG-mapper (for GO, KOG, KEGG)
echo "[7/8] Running eggNOG-mapper (optional)..."
# This step is optional and requires eggNOG database
# emapper.py -i "${TRANSCRIPTS}.transdecoder.pep" --cpu "$THREADS" -o eggnog_output

# For now, create placeholder files
echo "[7b] Creating GO/KEGG/KOG placeholders..."

# GO annotations (from UniProt mapping - simplified)
python3 << 'PYEOF'
# This would normally come from UniProt or InterProScan
with open("reference_trans_go.xls", "w") as out:
    out.write("SeqID\tAccession\tGOterm\tNameSpace\tDescription\n")
    out.write("# GO annotations need to be generated separately\n")

with open("reference_trans_kegg.xls", "w") as out:
    out.write("SeqID\tAccession\tAnnotation\n")
    out.write("# KEGG annotations need KAAS or KofamScan\n")

with open("reference_trans_kog.xls", "w") as out:
    out.write("SeqID\tKogID\tKogName\tKogClassName\tKogClassCode\n")
    out.write("# KOG annotations need eggNOG-mapper\n")

print("Created placeholder files")
PYEOF

# Step 8: Summary
echo "[8/8] Summary"
echo "=== Generated Files ==="
ls -lh reference_*.xls

echo ""
echo "=== Complete ==="
echo "Note: GO, KEGG, KOG annotations require additional tools:"
echo "  - GO: Use InterProScan or UniProt mapping"
echo "  - KEGG: Use KAAS or KofamScan"
echo "  - KOG: Use eggNOG-mapper"
