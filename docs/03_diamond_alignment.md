# Step 3: Diamond Protein Alignment

## Purpose

Align predicted protein sequences to UniProt SwissProt database to obtain best matches for inferring protein function and obtaining GO/KEGG annotations.

## Tool Used

**Diamond**: A protein alignment tool that is thousands of times faster than BLAST, suitable for large-scale annotation tasks.

## Commands

```bash
# Protein vs Protein alignment (blastp)
diamond blastp \
    --db /path/to/uniprot_sprot.dmnd \
    --query transcripts.transdecoder.pep \
    --outfmt 6 \
    --max-target-seqs 1 \
    --evalue 1e-5 \
    --threads 16 \
    --out diamond_blastp.outfmt6

# Nucleotide vs Protein alignment (blastx) - Optional
diamond blastx \
    --db /path/to/uniprot_sprot.dmnd \
    --query transcripts.fa \
    --outfmt 6 \
    --max-target-seqs 1 \
    --evalue 1e-5 \
    --threads 16 \
    --out diamond_blastx.outfmt6
```

## Parameter Details

### Common Parameters

| Parameter | Description | Recommended |
|-----------|-------------|-------------|
| `--db` | Diamond database path | (required) |
| `--query` | Query sequence file | (required) |
| `--out` | Output file | (required) |
| `--outfmt` | Output format | 6 (BLAST tabular) |
| `--max-target-seqs` | Maximum target sequences | 1 |
| `--evalue` | E-value threshold | 1e-5 |
| `--threads` | Thread count | 16 |
| `--id` | Minimum identity | optional |
| `--query-cover` | Minimum query coverage | optional |

### Output Format (--outfmt 6)

Standard BLAST tabular format with 12 columns:

| Column | Description |
|--------|-------------|
| 1 | Query sequence ID (qseqid) |
| 2 | Subject sequence ID (sseqid) |
| 3 | Identity percentage (pident) |
| 4 | Alignment length (length) |
| 5 | Mismatches (mismatch) |
| 6 | Gap openings (gapopen) |
| 7 | Query start (qstart) |
| 8 | Query end (qend) |
| 9 | Subject start (sstart) |
| 10 | Subject end (send) |
| 11 | E-value |
| 12 | Bit score |

## Database Preparation

### Create Diamond Database

```bash
# Create database from FASTA
diamond makedb --in uniprot_sprot.fasta.gz -d uniprot_sprot.dmnd

# Optional: Add taxid information
diamond makedb --in uniprot_sprot.fasta.gz -d uniprot_sprot.dmnd --taxonmap prot.accession2taxid.gz
```

### Recommended Databases

1. **SwissProt** (Recommended):
   - High-quality manual annotation
   - ~560,000 sequences
   - Download: `uniprot_sprot.fasta.gz`

2. **UniRef90**:
   - Clustered non-redundant
   - ~27,000,000 sequences
   - Good for distant species

3. **Species-specific databases**:
   - Can be built from NCBI
   - Improves annotation rate

## Parameter Tuning

### Strict Annotation (Reduce False Positives)
```bash
diamond blastp \
    --db db.dmnd \
    --query proteins.pep \
    --evalue 1e-10 \
    --id 70 \
    --query-cover 80 \
    --max-target-seqs 1 \
    --outfmt 6 \
    --out result.tsv
```

### Loose Annotation (Capture More Homologs)
```bash
diamond blastp \
    --db db.dmnd \
    --query proteins.pep \
    --evalue 1e-3 \
    --ultra-sensitive \
    --max-target-seqs 5 \
    --outfmt 6 \
    --out result.tsv
```

### Fast Mode
```bash
diamond blastp \
    --db db.dmnd \
    --query proteins.pep \
    --outfmt 6 \
    --block-size 10 \
    --threads 16 \
    --out result.tsv
```

## Output File Processing

### Extract Best Alignments

```python
import pandas as pd

# Read diamond results
df = pd.read_csv('diamond_blastp.outfmt6', 
                 sep='\t',
                 names=['qseqid','sseqid','pident','length','mismatch',
                        'gapopen','qstart','qend','sstart','send','evalue','bitscore'])

# Get best alignment for each query
best = df.sort_values('bitscore', ascending=False).groupby('qseqid').first().reset_index()
best.to_csv('best_hits.tsv', sep='\t', index=False)
```

## Common Issues

### Issue 1: Low Alignment Rate

**Possible causes:**
1. Species is too new/specific
2. Protein sequences too short
3. ORF prediction failed

**Solutions:**
- Use species-related database
- Check ORF prediction results
- Lower E-value threshold

### Issue 2: Insufficient Memory

**Solutions:**
```bash
# Use chunked processing
diamond blastp --block-size 5 --db db.dmnd --query proteins.pep --out result.tsv

# Or use --index-chunks
diamond --index-chunks 4
```

### Issue 3: Alignment Too Slow

**Solutions:**
- Increase thread count
- Use --ultra-sensitive (may actually be faster)
- Reduce query file size

### Issue 4: Database Too Large

**Solutions:**
```bash
# Extract species subset
diamond get_species_taxids -d db.dmnd --taxonlist 3702,3880,9606 > species.dmnd

# Or extract specific taxonomy
diamond subsetdb -d uniprot.dmnd -o plant.dmnd --taxon 33090  # Viridiplantae
```

## Performance Benchmark

| Database | Sequences | Index Size | 10K Query Time |
|----------|-----------|------------|----------------|
| SwissProt | 560K | 2.5GB | ~30 sec |
| UniRef90 | 27M | 45GB | ~10 min |
| NR | 250M | 400GB | ~1 hour |

## Verify Results

```bash
# Calculate alignment success rate
awk '{print $1}' diamond_blastp.outfmt6 | sort -u | wc -l

# Count unique alignments
awk '$11<1e-10' diamond_blastp.outfmt6 | wc -l

# View identity distribution
awk '{print $3}' diamond_blastp.outfmt6 | sort -n | uniq -c | tail -20
```
