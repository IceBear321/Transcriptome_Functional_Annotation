# Transcriptome Functional Annotation Pipeline

A complete pipeline for generating comprehensive functional annotations for transcriptome data.

## Overview

This pipeline generates functional annotations similar to `merged_annotations_qseqid_level.tsv`, including:
- UniProt/SwissProt best hits
- GO (Gene Ontology) annotations
- KEGG pathway annotations
- KOG ortholog annotations
- Pfam domain annotations

## Pipeline Steps

```
Input GTF → Extract Sequences → ORF Prediction → Diamond Alignment → Pfam → Merge Annotations
```

## Directory Structure

```
annotation_pipeline/
├── scripts/
│   ├── 00_download_databases.sh     # Download databases
│   ├── 01_prepare_reference.sh     # Prepare reference annotations
│   ├── 02_annotation_pipeline.sh   # Main annotation pipeline
│   └── merge_annotations.py        # Merge annotations
├── reference/                       # Database files
├── docs/
│   └── README.md                    # This file
└── run_full_pipeline.sh            # Run complete pipeline
```

## Quick Start

### 1. Install Dependencies

```bash
# Create conda environment
conda create -n annotation python=3.8
conda activate annotation

# Install required software
conda install -c bioconda diamond transdecoder hmmer bedtools
conda install -c conda-forge pandas

# Install eggNOG-mapper (optional)
pip install eggnog-mapper
```

### 2. Download Databases

```bash
bash scripts/00_download_databases.sh ./reference
```

### 3. Run Pipeline

```bash
# With default settings
bash run_full_pipeline.sh

# Or step by step
cd annotation_results
bash ../scripts/02_annotation_pipeline.sh \
    ../path/to/input.gtf \
    /path/to/genome.fa \
    ../path/to/reference.gtf \
    ../reference \
    . \
    16
```

## Input

- **GTF file**: Transcriptome annotation (e.g., `stringtie_long.hq.gtf_corrected.completed.gtf`)
- **Reference genome**: FASTA file
- **Reference GTF**: Reference annotation (optional, for comparison)

## Output

| File | Description |
|------|-------------|
| `transcripts.fa` | Transcript nucleotide sequences |
| `transcripts.transdecoder.pep` | Predicted protein sequences |
| `diamond_blastp.outfmt6` | Protein alignment results |
| `TrinotatePFAM.out` | Pfam domain annotations |
| `anno_uniprot_besthit.tsv` | UniProt best hits |
| `merged_annotations.tsv` | Final integrated annotation |

## merge_annotations.py

The key script for merging annotations:

```bash
python scripts/merge_annotations.py \
    --anno_uniprot_besthit annotation_results/anno_uniprot_besthit.tsv \
    --trans_uniprot reference/Medicago_Sativa_trans_uniprot.xls \
    --trans_go reference/Medicago_Sativa_trans_go.xls \
    --trans_kegg reference/Medicago_Sativa_trans_kegg.xls \
    --trans_kog reference/Medicago_Sativa_trans_kog.xls \
    --trans_pfam reference/Medicago_Sativa_trans_pfam.xls \
    -o merged_annotations.tsv \
    --one_row_per_qseqid
```

### Parameters

| Parameter | Description |
|-----------|-------------|
| `--anno_uniprot_besthit` | Best hit annotation from Diamond |
| `--trans_uniprot` | Transcript to UniProt mapping |
| `--trans_go` | GO annotations |
| `--trans_kegg` | KEGG pathway annotations |
| `--trans_kog` | KOG ortholog annotations |
| `--trans_pfam` | Pfam domain annotations |
| `-o` | Output file |
| `--one_row_per_qseqid` | Aggregate to one row per query |

## Reference Annotation Files

The pipeline requires reference annotation files in the following format:

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
Msa0503190-mRNA-1	K00859	koaE`dephospho-CoA kinase...
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

## Example Output Format

```
qseqid	accession	SeqID	Accession	GOterm	NameSpace	Description	kegg_accession	kegg_annotation	KogClassName	pfam_accession	HMMProfile	pfam_description
ONT.2.1	A0A072TI93	Msa0066300-mRNA-1	GO:0016310	phosphorylation	biological_process	K00859	coaE`dephospho-CoA kinase	PF01121.25	CoaE	Dephospho-CoA kinase
```

## Species-Specific Notes

For Medicago species:
1. Download Medicago truncatula reference from NCBI
2. Generate protein sequences
3. Run Diamond against UniProt
4. Use provided reference files for GO/KEGG/KOG/PFAM

## License

MIT License

## Citation

If you use this pipeline, please cite:
- Diamond: Buchfink B, Xie Y, Huson DH. Fast and sensitive protein alignment using DIAMOND. Nature Methods. 2015
- TransDecoder: Haas BJ, et al. TransDecoder: finding coding regions in genome sequences. 2013
