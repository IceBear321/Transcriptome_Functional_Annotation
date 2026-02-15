# Step 2: ORF Prediction (TransDecoder)

## Purpose

Predict Open Reading Frames (ORFs) from transcript nucleotide sequences to generate candidate protein sequences. This is the key step for converting transcriptome data to protein-level functional annotation.

## Tool Used

**TransDecoder**: A tool for identifying coding regions from genome or transcriptome data.

## Commands

```bash
# Step 1: Identify all long ORFs
TransDecoder.LongOrfs -t transcripts.fa -m 100

# Step 2: Predict coding regions
TransDecoder.Predict -t transcripts.fa
```

## Parameter Description

### TransDecoder.LongOrfs

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-t` | (required) | Input transcript FASTA |
| `-m` | 100 | Minimum ORF length (amino acids) |
| `-S` | false | Process only antisense strand |
| `-g` | false | Use GMAP alignment results |

### TransDecoder.Predict

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-t` | (required) | Input transcript FASTA |
| `--no_refine_starts` | false | Don't optimize start codons |
| `-m` | 100 | Minimum protein length |
| `--single_best_only` | false | Keep only best ORF |

## How It Works

1. **LongOrfs phase**: Scans all 6 reading frames (3 forward + 3 reverse), identifies ORFs with length >= 100 amino acids
2. **Predict phase**: Selects best ORFs using:
   - Log-likelihood score
   - Alignment score with known protein databases
   - Protein length
   - Coding score

## Output Files

| File | Description |
|------|-------------|
| `transcripts.fa.transdecoder.pep` | Predicted protein sequences |
| `transcripts.fa.transdecoder.cds` | CDS nucleotide sequences |
| `transcripts.fa.transdecoder.gff3` | GFF3 format annotation |
| `transcripts.fa.transdecoder.bed` | BED format positions |

## Protein Sequence Naming

TransDecoder generates protein IDs in format:
```
>TU00001|pilg1|m.1
MVLSPADKTNVKAAWGKVGAHAGEYGAEALERMFLSFPTTKTYFPHFDLSH...
```

Format explanation:
- `TU00001`: Transcript ID
- `pilg1`: Gene name (if available)
- `m.1`: Protein number (.p1, .p2, etc. for multiple ORFs)

## Common Issues

### Issue 1: Too Few Predicted Proteins

**Cause analysis:**
- Transcripts too short
- Minimum length threshold too high
- Many transcripts are non-coding RNA

**Solutions:**
```bash
# Lower minimum length threshold
TransDecoder.LongOrfs -t transcripts.fa -m 50
TransDecoder.Predict -t transcripts.fa -m 50
```

### Issue 2: Protein Naming Mismatch with Downstream Pipeline

**Issue:** TransDecoder output has .p suffix, need to remove for processing

**Solution:**
```bash
# Remove .p suffix
sed 's/\.p[0-9]*//g' transcripts.transdecoder.pep > proteins_clean.pep
```

### Issue 3: How to Use Known Proteins to Improve Prediction

**Method 1:** Use diamond alignment results to guide prediction
```bash
# Run diamond first
diamond blastx -d uniprot.dmnd -q transcripts.fa -o diamond.out

# Use alignment results
TransDecoder.Predict -t transcripts.fa --retain_diamond_hits diamond.out
```

**Method 2:** Use GMAP alignment results
```bash
# First map to reference proteins using GMAP
gmmap -d proteins.fa -t transcripts.fa -o gmap.gff

# Use alignment results
TransDecoder.LongOrfs -t transcripts.fa -g gmap.gff
TransDecoder.Predict -t transcripts.fa
```

### Issue 4: Predicted ORFs Contain Stop Codon *

**Note:** * in TransDecoder output indicates stop codon position

**Processing:**
```bash
# Remove stop codon markers
sed 's/\*$//' transcripts.transdecoder.pep > proteins.pep
```

## Parameter Tuning Suggestions

### For High-Quality Transcriptome
```bash
TransDecoder.LongOrfs -t transcripts.fa -m 100
TransDecoder.Predict -t transcripts.fa -m 100 --single_best_only
```

### For Low-Quality/New Species Transcriptome
```bash
# Keep more candidate ORFs
TransDecoder.LongOrfs -t transcripts.fa -m 50
TransDecoder.Predict -t transcripts.fa -m 50
```

### To Capture All Possible ORFs
```bash
# Don't filter, keep all
TransDecoder.LongOrfs -t transcripts.fa -m 30
TransDecoder.Predict -t transcripts.fa -m 30
```

## Comparison with Other Tools

| Tool | Advantages | Disadvantages |
|------|------------|---------------|
| TransDecoder | Designed for transcriptome | May predict overly long ORFs |
| ORFfinder | NCBI official tool | Slow |
| EMBOSS getorf | Fast | Complex threshold settings |

## Verify Output

```bash
# Count predicted proteins
grep -c '^>' transcripts.transdecoder.pep

# View length distribution
awk '/^>/{id=$0; next} {print length($0)}' transcripts.transdecoder.pep | sort -n | uniq -c | tail -20
```
