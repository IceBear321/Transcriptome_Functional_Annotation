# Transcriptome Functional Annotation Pipeline

Complete pipeline for generating comprehensive functional annotations from GTF annotation files.

## Overview

This pipeline generates molecular functional annotation information, including:
- **UniProt/SwissProt best hit**: Protein sequence alignment to SwissProt database
- **GO (Gene Ontology)**: Gene Ontology annotations
- **KEGG Pathway**: Metabolic pathway annotations
- **KOG (KEGG Orthology Groups)**: Ortholog group annotations
- **Pfam Domain**: Protein domain annotations

```
Input GTF → Extract Sequences → ORF Prediction → Diamond Alignment → Pfam Annotation → Merge Annotations
```

## Directory Structure

```
annotation_pipeline/
├── scripts/
│   ├── 00_download_databases.sh     # Download databases
│   ├── 01_prepare_reference.sh    # Prepare reference annotations
│   ├── 02_annotation_pipeline.sh  # Main annotation pipeline
│   ├── 03_generate_reference_annotations.sh  # Generate reference annotations from GTF
│   └── merge_annotations.py      # Merge annotation files
├── reference/                       # Database files directory
├── docs/
└── run_full_pipeline.sh            # Run complete pipeline
```

## Installation

### Create conda environment

```bash
# Create and activate environment
conda create -n annotation python=3.8
conda activate annotation

# Install core software
conda install -c bioconda diamond transdecoder hmmer bedtools gffread
conda install -c conda-forge pandas

# Install eggNOG-mapper (optional, for KOG/GO annotations)
pip install eggnog-mapper
```

### Dependency Software

| Software | Purpose | Installation |
|----------|---------|--------------|
| **Diamond** | Fast protein alignment | `conda install -c bioconda diamond` |
| **TransDecoder** | ORF prediction | `conda install -c bioconda transdecoder` |
| **HMMER/Pfam** | Protein domain annotation | `conda install -c bioconda hmmer` |
| **gffread** | Extract sequences from GTF | `conda install -c bioconda gffread` |
| **bedtools** | Genome operations | `conda install -c bioconda bedtools` |
| **pandas** | Data processing | `conda install -c conda-forge pandas` |

## Database Download

### Manual Download (Recommended)

1. **UniProt SwissProt**:
   - Download: https://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/complete/
   - File: `uniprot_sprot.fasta.gz`
   - Create Diamond database: `diamond makedb --in uniprot_sprot.fasta.gz -d uniprot_sprot.dmnd`

2. **Pfam**:
   - Download: https://ftp.ebi.ac.uk/pub/databases/Pfam/current_release/
   - File: `Pfam-A.hmm.gz`
   - After decompressing: `hmmpress Pfam-A.hmm`

3. **eggNOG** (optional):
   - Install via Python: `python -m eggnog_downloader.downloader --data_dir ./eggnog --taxid TAXID`
   - TAXID reference: Human=9606, Mouse=10090, Arabidopsis=3702, Medicago=3880

4. **KEGG**:
   - Requires manual download from https://www.genome.jp/tools/kaas/
   - Or use local tool KofamScan

### Auto Download Script

```bash
bash scripts/00_download_databases.sh ./reference 16
```

Parameters:
- `$1`: Database save directory (default: ./reference)
- `$2`: Number of threads (default: 16)

## Quick Start

### Option 1: Run Full Pipeline

```bash
bash run_full_pipeline.sh \
    /path/to/input.gtf \          # Input GTF file
    /path/to/genome.fa \          # Reference genome FASTA
    /path/to/reference.gtf \       # Reference GTF (optional)
    ./reference \                 # Database directory
    ./annotation_results          # Output directory
```

### Option 2: Step-by-Step

```bash
# Step 1: Run main annotation pipeline
cd annotation_results
bash ../scripts/02_annotation_pipeline.sh \
    /path/to/input.gtf \
    /path/to/genome.fa \
    /path/to/reference.gtf \
    ../reference \
    . \
    16

# Step 2: Generate reference annotations
bash ../scripts/03_generate_reference_annotations.sh \
    /path/to/reference.gtf \
    reference_transcripts.fa \
    "" \
    Reference \
    16 \
    /path/to/genome.fa

# Step 3: Merge annotations
python3 ../scripts/merge_annotations.py \
    --anno_uniprot_besthit anno_uniprot_besthit.tsv \
    --trans_uniprot reference_trans_uniprot.xls \
    --trans_go reference_trans_go.xls \
    --trans_kegg reference_trans_kegg.xls \
    --trans_kog reference_trans_kog.xls \
    --trans_pfam reference_trans_pfam.xls \
    -o merged_annotations.tsv \
    --one_row_per_qseqid
```

## Input File Formats

### GTF File Format Requirements

GTF file must contain the following attributes:
- `transcript_id`: Transcript ID
- `gene_id`: Gene ID
- `gene_name`: Gene name (optional)

Example:
```
chr1    StringTie   transcript  11873   14409   .   +   .   gene_id "MSTRG.1"; transcript_id "MSTRG.1.1"; gene_name "AT1G01020";
```

### Genome FASTA

Standard FASTA format, supports .gz compression:
```
>chr1
ATGCGCTAGCTAGCTAGCTAGCTAGCTAGCTA...
>chr2
GCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTA...
```

## Output File Description

| File | Description |
|------|-------------|
| `transcripts.fa` | Transcript nucleotide sequences |
| `transcripts.transdecoder.pep` | Predicted protein sequences (ORF) |
| `diamond_blastp.outfmt6` | Diamond protein alignment results |
| `TrinotatePFAM.out` | Pfam domain annotations |
| `anno_uniprot_besthit.tsv` | UniProt best hit |
| `merged_annotations.tsv` | Final integrated annotation |

### merged_annotations.tsv Output Column Description

| Column | Description | Example |
|--------|-------------|---------|
| qseqid | Query sequence ID | ONT.2.1 |
| accession | UniProt accession | A0A072TI93 |
| SeqID | Transcript ID | Msa0066300-mRNA-1 |
| GOterm | GO term | GO:0016310 |
| NameSpace | GO namespace | biological_process |
| Description | Description | phosphorylation |
| kegg_accession | KEGG accession | K00859 |
| kegg_annotation | KEGG annotation | coaE dephospho-CoA kinase |
| KogClassName | KOG classification name | Chaperone HSP104 |
| pfam_accession | Pfam ID | PF01121.25 |
| HMMProfile | HMM model name | CoaE |
| pfam_description | Pfam description | Dephospho-CoA kinase |

## Script Details

### 00_download_databases.sh

Download and prepare required database files.

**Parameters:**
| Parameter | Default | Description |
|-----------|----------|-------------|
| `$1` | ./reference | Database save directory |
| `$2` | 16 | Number of parallel threads |

**Output Files:**
- `uniprot_sprot.fasta.gz`: SwissProt sequences
- `uniprot_sprot.dmnd`: Diamond database
- `Pfam-A.hmm`: Pfam HMM models

**Notes:**
- First download requires ~2GB space
- Diamond database creation may take a long time
- KEGG requires manual download from website

---

### 02_annotation_pipeline.sh

Main annotation pipeline script.

**Parameters:**
| Parameter | Description | Example |
|-----------|-------------|---------|
| `$1` | Input GTF file | `/path/to/stringtie.gtf` |
| `$2` | Reference genome FASTA | `/path/to/genome.fa` |
| `$3` | Reference GTF (optional) | `/path/to/ref.gtf` |
| `$4` | Database directory | `./reference` |
| `$5` | Output directory | `./annotation_results` |
| `$6` | Thread count | 16 |

**Steps:**

#### Step 1: Extract transcript sequences
```bash
gffread input.gtf -g genome.fa -w transcripts.fa
```

#### Step 2: ORF prediction
```bash
TransDecoder.LongOrfs -t transcripts.fa -m 100
TransDecoder.Predict -t transcripts.fa
```

#### Step 3: Diamond alignment
```bash
diamond blastp --db uniprot_sprot.dmnd --query transcripts.transdecoder.pep \
    --outfmt 6 --max-target-seqs 1 --evalue 1e-5 --threads 16
```

#### Step 4: Pfam annotation
```bash
hmmscan --cpu 16 --domtblout TrinotatePFAM.out Pfam-A.hmm proteins.pep
```

---

### 03_generate_reference_annotations.sh

Generate reference annotation files from GTF for downstream merging.

**Parameters:**
| Parameter | Description |
|-----------|-------------|
| `$1` | Input GTF file |
| `$2` | Output transcript FASTA name |
| `$3` | Reference protein FASTA (optional) |
| `$4` | Output prefix |
| `$5` | Thread count |
| `$6` | Genome FASTA |

**Output Files:**
- `reference_trans_uniprot.xls`
- `reference_trans_go.xls`
- `reference_trans_kegg.xls`
- `reference_trans_kog.xls`
- `reference_trans_pfam.xls`

---

### merge_annotations.py

Integrate multiple annotation sources into final annotation file.

**Parameters:**
| Parameter | Required | Description |
|-----------|----------|-------------|
| `--anno_uniprot_besthit` | ✓ | Diamond best hit results |
| `--trans_uniprot` | ✓ | Transcript → UniProt mapping |
| `--trans_go` | ✓ | GO annotation file |
| `--trans_kegg` | ✓ | KEGG annotation file |
| `--trans_kog` | ✓ | KOG annotation file |
| `--trans_pfam` | ✓ | Pfam annotation file |
| `-o/--output` | ✓ | Output file path |
| `--one_row_per_qseqid` | ✗ | One row per query |

## Reference Annotation File Formats

### trans_uniprot.xls
```
SeqID	Accession	Annotation
Msa0503190-mRNA-1	tr|G7KXW3|G7KXW3_MEDTR	Description...
```

### trans_go.xls
```
SeqID	Accession	GOterm	NameSpace	Description
Msa0503190-mRNA-1	GO:0008150	biological_process	Process...
```

### trans_kegg.xls
```
SeqID	Accession	Annotation
Msa0503190-mRNA-1	K00859	koaE dephospho-CoA kinase...
```

### trans_kog.xls
```
SeqID	KogID	KogName	KogClassName	KogClassCode
Msa0000050-mRNA-1	KOG1051	Chaperone HSP104	Posttranslational...
```

### trans_pfam.xls
```
SeqID	Accession	HMMProfile	Description
Msa0000010-mRNA-1	PF00004	AAA	ATPase family...
```

## Common Issues

### Issue 1: Low annotation rate

**Cause analysis:**
- Transcripts too short (no ORF)
- New species/specific genes
- ORF prediction failed

**Solutions:**
- Add species-specific database
- Lower Diamond E-value threshold
- Use Trinity for de novo annotation
- Check if ORF prediction is correct

### Issue 2: Diamond alignment takes too long

**Solutions:**
- Increase thread count
- Use --ultra-sensitive parameter
- Pre-build database index

### Issue 3: Pfam annotation failed

**Check:**
- Is HMM database properly decompressed?
- Was hmmpress run?
- Is protein sequence format correct?

### Issue 4: Memory insufficient

**Solutions:**
- Reduce batch processing size
- Use --block-size parameter
- Increase swap space

### Issue 5: GTF format errors

**Common errors:**
- Missing required attribute fields
- Chromosome names don't match
- Coordinates out of range

**Check:**
```bash
# Validate GTF format
gffread -E input.gtf -o /dev/null 2>&1

# Count transcripts
grep -c 'transcript' input.gtf
```

## Species-Specific Annotations

### Medicago (Medicago sativa)

1. Download reference genome
2. Use StringTie for annotation
3. Run this pipeline
4. Use Medicago truncatula (TAXID: 3880) database

### Arabidopsis (Arabidopsis thaliana)

- TAXID: 3702
- Recommended database: TAIR
- Can use Araport11 annotation

### Rice (Oryza sativa)

- TAXID: 4530
- Recommended: MSU annotation

## Performance Optimization

### Parallelization

```bash
# Use more threads
THREADS=32 bash scripts/02_annotation_pipeline.sh ...

# Use GNU parallel for batch processing
parallel -j 8 diamond blastp ::: *.pep
```

### Memory Optimization

```bash
# Diamond chunked processing
diamond blastp --db db.dmnd --query query.fa --out out.tsv \
    --block-size 10 --threads 16
```

## Citation

If using this pipeline, please cite:
- **Diamond**: Buchfink B, Xie Y, Huson DH. Fast and sensitive protein alignment using DIAMOND. Nature Methods. 2015
- **TransDecoder**: Haas BJ, et al. TransDecoder: finding coding regions in genome sequences. 2013
- **HMMER**: Finn RD, Clements J, Eddy SR. HMMER web server: interactive sequence similarity searching. Nucleic Acids Research. 2011

## License

MIT License

## Contact

For issues: https://github.com/IceBear321/Transcriptome_Functional_Annotation/issues
