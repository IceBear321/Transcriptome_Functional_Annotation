# Step 1: Extract Transcript Sequences

## Purpose

Extract transcript nucleotide sequences from GTF annotation file and reference genome FASTA file. This is the foundation for the entire annotation pipeline, as subsequent ORF prediction and protein alignment depend on transcript sequences.

## Tool Used

**gffread**: Part of the GFFutils toolkit, used to extract sequences from GTF/GFF files.

## Command

```bash
gffread input.gtf -g genome.fa -w transcripts.fa
```

## Parameter Description

| Parameter | Description | Example |
|-----------|-------------|---------|
| `input.gtf` | Input GTF file | `stringtie_long.hq.gtf` |
| `-g genome.fa` | Reference genome FASTA | `/path/to/genome.fa` |
| `-w transcripts.fa` | Output transcript FASTA | `transcripts.fa` |

## Other Useful Parameters

```bash
# Extract CDS sequences
gffread input.gtf -g genome.fa -x cds.fa

# Extract protein sequences (requires CDS annotation in GTF)
gffread input.gtf -g genome.fa -y protein.fa

# Only keep transcripts
gffread input.gtf -g genome.fa -w transcripts.fa -t transcript

# Add genomic coordinates to sequence IDs
gffread input.gtf -g genome.fa -w transcripts.fa -W
```

## Input File Requirements

### GTF Format Requirements

1. Must contain `transcript` type lines
2. Must have `transcript_id` attribute
3. Chromosome names in genome FASTA must exactly match those in GTF

Example GTF line:
```
chr1    StringTie   transcript  11873   14409   .   +   .   gene_id "MSTRG.1"; transcript_id "MSTRG.1.1";
```

### Genome FASTA Format

Standard FASTA format, chromosome names must match GTF:
```
>chr1
ATGCGCTAGCTAGCTAGCTAGCTAGCTAGCTA...
>chr2
GCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTA...
```

## Output File Format

FASTA format, each sequence header contains transcript ID:

```
>MSTRG.1.1
ATGCGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTA...
>MSTRG.2.1
GCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTA...
```

## Common Issues

### Issue 1: Chromosome Name Mismatch

**Error:**
```
Error: chromosome 'chr1' not found in genome file!
```

**Solution:**
Check if chromosome naming is consistent between GTF and genome FASTA. May need to unify naming:
```bash
# Add chr prefix consistently
sed -i 's/^>/>chr/' genome.fa

# Or remove chr prefix
sed -i 's/^chr//' genome.fa
```

### Issue 2: Missing Transcripts in GTF

**Check:**
```bash
# Count transcripts in GTF
grep -c 'transcript' input.gtf

# Check for correct attributes
grep 'transcript' input.gtf | head -5
```

### Issue 3: Extracted Sequence Count Lower than Expected

Possible causes:
- Some transcripts in GTF don't have valid coordinate ranges
- Genome version mismatch

**Solution:**
```bash
# Validate GTF file
gffread -E input.gtf -o /dev/null 2>&1

# Check if GTF transcripts are complete
gffread input.gtf -g genome.fa -w /dev/null -v
```

## Performance Tips

- gffread supports multithreading, but main bottleneck is file I/O
- For large genomes, pre-create faidx index:
```bash
samtools faidx genome.fa
```
