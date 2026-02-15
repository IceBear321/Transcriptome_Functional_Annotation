# Troubleshooting Guide

This document lists common issues and solutions when using the transcriptome functional annotation pipeline.

## Table of Contents

1. [Data Preparation Issues](#data-preparation-issues)
2. [Installation Issues](#installation-issues)
3. [Runtime Issues](#runtime-issues)
4. [Output Issues](#output-issues)
5. [Performance Issues](#performance-issues)

---

## Data Preparation Issues

### Issue 1: Incorrect GTF Format

**Symptoms:**
```
Error: gffread: Cannot get coordinates from transcript line
```

**Check:**
```bash
# Check if GTF has correct transcript lines
grep 'transcript' input.gtf | head -3

# Validate GTF format
gffread -E input.gtf -o /dev/null 2>&1
```

**Solutions:**
- Ensure GTF contains `transcript` type lines
- Ensure each line has 9 columns
- Ensure `transcript_id` attribute is present

### Issue 2: Missing Genome FASTA Index

**Symptoms:**
```
Error: Could not locate fasta index file for genome.fa
```

**Solutions:**
```bash
# Create faidx index
samtools faidx genome.fa

# Or using gffread
gffread -E input.gtf -g genome.fa -o /dev/null
```

### Issue 3: Chromosome Name Mismatch

**Symptoms:**
```
Error: chromosome 'chr1' not found in genome file!
```

**Check:**
```bash
# View chromosomes in GTF
cut -f1 input.gtf | sort -u | head -10

# View chromosomes in genome FASTA
grep '^>' genome.fa | head -10
```

**Solutions:**
```bash
# Add chr prefix consistently
sed -i 's/^>/>chr/' genome.fa
sed -i 's/\tchr/\t/g' input.gtf

# Or remove chr prefix
sed -i 's/^chr//' genome.fa
```

---

## Installation Issues

### Issue 4: Conda Environment Creation Failed

**Symptoms:**
```
CondaHTTPError: HTTP error 404
```

**Solutions:**
```bash
# Clear cache
conda clean --all

# Switch channels
conda config --add channels conda-forge
conda config --add channels bioconda
```

### Issue 5: Diamond Database Creation Failed

**Symptoms:**
```
Error: Error opening sequence file
```

**Solutions:**
```bash
# Check file integrity
file uniprot_sprot.fasta.gz

# Check after decompression
gunzip -c uniprot_sprot.fasta.gz | head -10

# Re-download
wget -c ftp://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/complete/uniprot_sprot.fasta.gz
```

### Issue 6: TransDecoder Not Found

**Symptoms:**
```
Command 'TransDecoder.LongOrfs' not found
```

**Solutions:**
```bash
# Activate conda environment
conda activate annotation

# Or reinstall
conda install -c bioconda transdecoder -y

# Confirm installation
which TransDecoder.LongOrfs
```

---

## Runtime Issues

### Issue 7: ORF Prediction Failed

**Symptoms:**
```
No ORFs found in transcripts
```

**Possible causes:**
1. Transcripts too short
2. Sequence not using standard genetic code
3. Sequence extraction from GTF has errors

**Solutions:**
```bash
# Check transcript length distribution
awk '/^>/{id=$0; next} {print length($0)}' transcripts.fa | sort -n | tail -10

# Reduce minimum ORF length
TransDecoder.LongOrfs -t transcripts.fa -m 30

# Check sequence quality
head -20 transcripts.fa
```

### Issue 8: Diamond Alignment Returns No Results

**Symptoms:**
```
0 hits found
```

**Check:**
```bash
# Check protein file
grep -c '^>' proteins.pep

# Check database
diamond makedb --in proteins.pep --db test --validate

# Check sequence format
head -5 proteins.pep
```

**Solutions:**
- Lower E-value threshold
- Check if ORF prediction succeeded
- Use species-specific database

### Issue 9: Pfam Annotation Failed

**Symptoms:**
```
Error: hmmscan crashed
```

**Solutions:**
```bash
# Check Pfam database
hmmstat Pfam-A.hmm

# Re-create index
hmmpress Pfam-A.hmm

# Check protein file format
head -3 proteins.pep
```

---

## Output Issues

### Issue 10: Merge Annotations Failed

**Symptoms:**
```
KeyError: 'SeqID'
```

**Check:**
```bash
# Check column names
head -1 anno_uniprot_besthit.tsv
head -1 trans_uniprot.xls
```

**Solutions:**
- Confirm column names match
- Check file delimiter (must be tab)
- Remove BOM

```bash
# Check delimiter
file merged_annotations.tsv

# Remove BOM
sed -i '1s/^\xEF\xBB\xBF//' file.tsv
```

### Issue 11: Low Annotation Rate

**Symptoms:**
```
Only 20% of transcripts have functional annotations
```

**Analysis:**
```bash# Calculate success rate at each step
echo "Transcripts: $(grep -c '^>' transcripts.fa)"
echo "Proteins: $(grep -c '^>' proteins.pep)"
echo "Diamond hits: $(cut -f1 diamond.out | sort -u | wc -l)"
echo "Pfam annotations: $(cut -f3 TrinotatePFAM.out | sort -u | wc -l)"
```

**Solutions to improve annotation rate:**
1. Add species-specific database
2. Lower E-value threshold
3. Use more databases (UniRef90, NR)
4. Use InterProScan for additional annotations

---

## Performance Issues

### Issue 12: Slow Runtime

**Symptoms:**
```
Pipeline runs for more than 24 hours
```

**Solutions:**
1. **Increase threads**
```bash
THREADS=32 bash run_full_pipeline.sh
```

2. **Reduce query file size**
```bash
# Filter short sequences
awk '/^>/{keep=length($0)>500} keep' proteins.pep > proteins_filtered.pep
```

3. **Use fast mode**
```bash
diamond blastp --ultra-sensitive --db db.dmnd --query proteins.pep
```

### Issue 13: Out of Memory

**Symptoms:**
```
Killed (out of memory)
```

**Solutions:**

1. **Reduce thread count**
```bash
THREADS=4 bash scripts/02_annotation_pipeline.sh
```

2. **Use chunked processing**
```bash
# Diamond chunking
diamond blastp --block-size 5 --db db.dmnd --query proteins.pep

# HMMER chunking
hmmscan --max -E 1e-5 Pfam-A.hmm proteins.pep
```

3. **Increase swap**
```bash
# Check current memory
free -h

# Add swap (e.g., 4GB)
sudo dd if=/dev/zero of=/swapfile bs=1G count=4
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### Issue 14: Insufficient Disk Space

**Symptoms:**
```
No space left on device
```

**Solutions:**
```bash
# Clean temporary files
rm -rf tmp/

# Clean conda cache
conda clean -a

# Use smaller database
# Use SwissProt instead of NR
```

---

## Debugging Tips

### Enable Debug Mode

```bash
# Add at script beginning
set -x  # Print executed commands

# Or use bash -x
bash -x run_full_pipeline.sh
```

### Check Intermediate Results

```bash
# Check each step output
ls -lh annotation_results/

# View logs
tail -50 pfam.log
tail -50 diamond.log
```

### Test with Small Dataset

```bash
# Extract small test data
head -100 input.gtf > test.gtf
head -100 genome.fa > test.fa

# Run test
bash run_full_pipeline.sh test.gtf test.fa
```

---

## Getting Help

If the above solutions don't resolve your issue:

1. Check all software versions
2. Check detailed error messages in log files
3. Search similar issues: https://github.com/IceBear321/Transcriptome_Functional_Annotation/issues
4. When opening an issue, include:
   - Complete error message
   - Command used
   - System environment (`uname -a`)
   - Software versions (`conda list` or `diamond --version`)
