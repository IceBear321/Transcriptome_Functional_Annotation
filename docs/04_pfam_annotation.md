# Step 4: Pfam Protein Domain Annotation

## Purpose

Annotate predicted proteins with protein domains using the Pfam database to identify protein families and conserved regions, providing additional information for functional annotation.

## Tool Used

**HMMER (hmmscan)**: Uses Hidden Markov Models (HMM) for protein domain alignment.

## Command

```bash
hmmscan --cpu 16 \
    --domtblout TrinotatePFAM.out \
    /path/to/Pfam-A.hmm \
    transcripts.transdecoder.pep > pfam.log
```

## Parameter Description

| Parameter | Description | Recommended |
|-----------|-------------|-------------|
| `--cpu` | Number of parallel threads | 16 |
| `--domtblout` | Domain table output file | (required) |
| `-E` | Global E-value threshold | 1e-5 |
| `--domE` | Domain E-value threshold | 1e-5 |
| `--domT` | Domain bitscore threshold | optional |

## Output Format

### Domain Table Format

| Column | Description |
|--------|-------------|
| 1 | Target name (Pfam ID) |
| 2 | Target accession |
| 3 | Query name |
| 4 | Query accession |
| 5 | Global E-value |
| 6 | Global bitscore |
| 7 | Global coverage |
| 8 | Number of sequences |
| 9 | Number of domains |
| 10 | Domain E-value |
| 11 | Domain bitscore |
| 12 | Domain coverage |
| 13-14 | Domain position in query |
| 15-16 | Domain position in HMM |
| 17 | Amino acids |
| 18-22 | Description |

## Database Preparation

### Download Pfam Database

```bash
# Method 1: Download from EBI
wget -O Pfam-A.hmm.gz \
    ftp://ftp.ebi.ac.uk/pub/databases/Pfam/current_release/Pfam-A.hmm.gz
gunzip Pfam-A.hmm.gz

# Method 2: Use conda
conda install -c bioconda hmmer
```

### Create HMM Index

```bash
# Compress database (required)
hmmpress Pfam-A.hmm

# Verify
hmmstat Pfam-A.hmm
```

## Parameter Tuning

### Strict Annotation
```bash
hmmscan --cpu 16 \
    --domtblout strict_pfam.out \
    -E 1e-10 --domE 1e-10 \
    Pfam-A.hmm proteins.pep
```

### Loose Annotation (Capture More)
```bash
hmmscan --cpu 16 \
    --domtblout loose_pfam.out \
    -E 1e-3 --domE 1e-3 \
    Pfam-A.hmm proteins.pep
```

### Only High Confidence
```bash
# bitscore > 20
hmmscan --cpu 16 \
    --domtblout highconf_pfam.out \
    --domT 20 \
    Pfam-A.hmm proteins.pep
```

## Process Pfam Output

### Extract Best Domain Matches

```python
import pandas as pd

# Read domain table
with open('TrinotatePFAM.out') as f:
    lines = f.readlines()

results = []
for line in lines:
    if line.startswith('#') or not line.strip():
        continue
    fields = line.split()
    results.append({
        'query_id': fields[2],
        'pfam_id': fields[1],
        'evalue': float(fields[10]),
        'bitscore': float(fields[11]),
        'q_start': int(fields[15]),
        'q_end': int(fields[16]),
        'description': ' '.join(fields[22:])
    })

df = pd.DataFrame(results)

# Get best match for each query
best = df.sort_values('bitscore', ascending=False).groupby('query_id').first().reset_index()
best.to_csv('pfam_best.tsv', sep='\t', index=False)
```

## Common Issues

### Issue 1: Low Annotation Rate

**Possible causes:**
1. Proteins too short
2. Species-specific proteins
3. Outdated database version

**Solutions:**
- Check protein length distribution
- Update Pfam database
- Use InterProScan for supplementary annotations

### Issue 2: Running Time Too Long

**Solutions:**
```bash
# Increase threads
hmmscan --cpu 32 ...

# Use hmmsearch (for single sequence)
hmmsearch --cpu 16 Pfam-A.hmm protein.pep
```

### Issue 3: Insufficient Memory

**Solutions:**
```bash
# Use --max size limit
hmmscan --cpu 16 --max Pfam-A.hmm proteins.pep
```

## Pfam ID Format Explanation

- **PFxxxxx**: Pfam family ID (e.g., PF00001)
- **PFxxxxx_xx**: Homologous family (clan)

### Common Pfam Families

| Pfam ID | Name | Function |
|---------|------|----------|
| PF00004 | AAA | ATPase family |
| PF00069 | PKinase | Protein kinase |
| PF00118 | Cpn60_TCP1 | Molecular chaperone |
| PF00533 | BRCT | DNA repair |
| PF07679 | I-set | Immunoglobulin |

## Verify Results

```bash
# Count proteins with Pfam annotation
awk '{print $3}' TrinotatePFAM.out | sort -u | wc -l

# View most common Pfam
awk '!/^#/{print $1}' TrinotatePFAM.out | sort | uniq -c | sort -rn | head -20

# View E-value distribution
awk '!/^#/{print $10}' TrinotatePFAM.out | awk '{if($1<1e-10) print "high"; else if($1<1e-5) print "med"; else print "low"}' | sort | uniq -c
```

## Comparison with Other Tools

| Tool | Advantages | Database |
|------|------------|----------|
| HMMER/Pfam | Authoritative, accurate annotation | Pfam |
| InterProScan | Comprehensive annotation | Multiple databases |
| CDD/NCBI | Conserved domains | CDD |
| SMART | Signaling pathways | SMART |
