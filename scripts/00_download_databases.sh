#!/bin/bash
# =============================================================================
# 00_download_databases.sh
# Download and prepare required databases
# =============================================================================

set -euo pipefail

DB_DIR="${1:-./reference}"
THREADS="${2:-16}"

mkdir -p "$DB_DIR"

echo "=== Downloading Databases ==="

# 1. UniProt SwissProt
echo "[1/4] Downloading UniProt SwissProt..."
if [ ! -f "$DB_DIR/uniprot_sprot.fasta.gz" ]; then
    wget -q -O "$DB_DIR/uniprot_sprot.fasta.gz" \
        ftp://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/complete/uniprot_sprot.fasta.gz
fi

# Create Diamond database
if [ ! -f "$DB_DIR/uniprot_sprot.dmnd" ]; then
    diamond makedb --in "$DB_DIR/uniprot_sprot.fasta.gz" -d "$DB_DIR/uniprot_sprot.dmnd" --threads "$THREADS"
fi

# 2. Pfam
echo "[2/4] Downloading Pfam..."
if [ ! -f "$DB_DIR/Pfam-A.hmm.gz" ]; then
    wget -q -O "$DB_DIR/Pfam-A.hmm.gz" \
        ftp://ftp.ebi.ac.uk/pub/databases/Pfam/current_release/Pfam-A.hmm.gz
fi
if [ ! -f "$DB_DIR/Pfam-A.hmm" ]; then
    gunzip -c "$DB_DIR/Pfam-A.hmm.gz" > "$DB_DIR/Pfam-A.hmm"
    hmmpress "$DB_DIR/Pfam-A.hmm"
fi

# 3. eggNOG (optional)
echo "[3/4] Downloading eggNOG database..."
if [ ! -d "$DB_DIR/eggnog" ]; then
    python -m eggnog_downloader.downloader --data_dir "$DB_DIR/eggnog" --taxid 3880  # Medicago
fi

# 4. KEGG (optional - requires registration)
echo "[4/4] KEGG annotation requires manual download from https://www.genome.jp/tools/kaas/"

echo "=== Database Download Complete ==="
echo "Database directory: $DB_DIR"
