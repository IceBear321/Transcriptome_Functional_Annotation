# Step 5: Merge Annotation Files (merge_annotations.py)

## Purpose

Integrate annotation information from multiple sources (Diamond alignment results, GO, KEGG, KOG, Pfam) into a unified annotation file for easier downstream analysis and visualization.

## Script Functions

1. **Read multiple annotation sources**: Read data from different annotation file formats
2. **Build index mapping**: Establish mapping between transcript IDs and functional annotations via UniProt accession
3. **Merge and integrate**: Combine all annotations into a single record
4. **Deduplicate and aggregate**: Handle one-to-many relationships (e.g., one transcript with multiple GO terms)

## Usage

### Basic Usage

```bash
python scripts/merge_annotations.py \
    --anno_uniprot_besthit anno_uniprot_besthit.tsv \
    --trans_uniprot reference_trans_uniprot.xls \
    --trans_go reference_trans_go.xls \
    --trans_kegg reference_trans_kegg.xls \
    --trans_kog reference_trans_kog.xls \
    --trans_pfam reference_trans_pfam.xls \
    -o merged_annotations.tsv \
    --one_row_per_qseqid
```

### Parameter Description

| Parameter | Required | Description | Example |
|-----------|----------|-------------|---------|
| `--anno_uniprot_besthit` | Yes | Diamond best hit file | `anno_uniprot_besthit.tsv` |
| `--trans_uniprot` | Yes | UniProt mapping file | `trans_uniprot.xls` |
| `--trans_go` | Yes | GO annotation file | `trans_go.xls` |
| `--trans_kegg` | Yes | KEGG annotation file | `trans_kegg.xls` |
| `--trans_kog` | Yes | KOG annotation file | `trans_kog.xls` |
| `--trans_pfam` | Yes | Pfam annotation file | `trans_pfam.xls` |
| `-o, --output` | Yes | Output file path | `merged_annotations.tsv` |
| `--one_row_per_qseqid` | No | One row per query | Flag |

## Input File Formats

### anno_uniprot_besthit.tsv

Best hit results from Diamond, tab-separated:

```
qseqid	accession	entry_name	reviewed	pident	align_len	evalue	bitscore	description
MSTRG.1.1	P12345	ATP synthase	reviewed	95.5	500	1e-100	450.2	ATP synthase subunit alpha
```

### trans_uniprot.xls

Transcript to UniProt mapping, tab-separated:

```
SeqID	Accession	Annotation
Msa000001-mRNA-1	sp|P12345|ATP5A1	ATP synthase subunit alpha
Msa000002-mRNA-1	sp|P54369|ATPA	ATP synthase subunit beta
```

### trans_go.xls

GO annotations, tab-separated:

```
SeqID	Accession	GOterm	NameSpace	Description
Msa000001-mRNA-1	GO:0015078	ATP synthase activity	molecular_function	Catalyzes the synthesis of ATP
Msa000001-mRNA-1	GO:0015986	ATP synthesis coupled proton transport	biological_process	Process of ATP synthesis
```

### trans_kegg.xls

KEGG pathway annotations:

```
SeqID	Accession	Annotation
Msa000001-mRNA-1	K02136	ATP synthase
```

### trans_kog.xls

KOG ortholog annotations:

```
SeqID	KogID	KogName	KogClassName	KogClassCode
Msa000001-mRNA-1	KOG0266	ATP synthase alpha/beta	Energy production	C
```

### trans_pfam.xls

Pfam domain annotations:

```
SeqID	Accession	HMMProfile	Description
Msa000001-mRNA-1	PF00136	ATP_synt_B	ATP synthase B chain
```

## Output File Format

### merged_annotations.tsv

Integrated annotation file with columns:

| Column Name | Description | Source |
|------------|-------------|--------|
| qseqid | Query sequence ID | Diamond result |
| accession | UniProt accession | Diamond result |
| SeqID | Transcript ID | Mapping file |
| GOterm | GO term | GO annotation |
| NameSpace | GO namespace | GO annotation |
| Description | GO description | GO annotation |
| kegg_accession | KEGG ID | KEGG annotation |
| kegg_annotation | KEGG annotation | KEGG annotation |
| KogClassName | KOG classification name | KOG annotation |
| pfam_accession | Pfam ID | Pfam annotation |
| HMMProfile | HMM model name | Pfam annotation |
| pfam_description | Pfam description | Pfam annotation |

### Output Example

```
qseqid	accession	SeqID	GOterm	NameSpace	Description	kegg_accession	kegg_annotation	KogClassName	pfam_accession	HMMProfile	pfam_description
MSTRG.1.1	A0A072TI93	Msa0066300-mRNA-1	GO:0016310	biological_process	phosphorylation	K00859	coaE dephospho-CoA kinase	PF01121.25	CoaE	Dephospho-CoA kinase
```

## Processing Logic

### 1. Read and Normalize

```python
# Read all input files
anno = pd.read_csv(besthit_file, sep='\t')
trans_uniprot = pd.read_csv(uniprot_file, sep='\t')

# Normalize UniProt accession (remove sp| prefix)
def normalize_core_uniprot(acc):
    parts = acc.split('|')
    if len(parts) >= 2:
        return parts[1]  # Keep only core accession
    return acc
```

### 2. Build Index

```python
# Build UniProt accession -> Transcript ID mapping
# One UniProt may correspond to multiple transcripts
acc_to_seqids = trans_uniprot.groupby('core_acc')['SeqID'].apply(list).to_dict()
```

### 3. Merge Annotations

```python
# Connect all annotation tables via SeqID
result = base.merge(go_agg, on='SeqID', how='left')
result = result.merge(kegg_agg, on='SeqID', how='left')
result = result.merge(kog_agg, on='SeqID', how='left')
result = result.merge(pfam_agg, on='SeqID', how='left')
```

### 4. Aggregation Processing

For one-to-many relationships (e.g., one protein with multiple GO terms), merge with semicolon:

```
GO:0016310;GO:0006468;GO:0006754
```

## Common Issues

### Issue 1: Record Count Decreased After Merge

**Cause:** UniProt accession doesn't map to transcript ID

**Solutions:**
- Check if SeqID in trans_uniprot.xls is correct
- Confirm format matches (case-sensitive)

### Issue 2: Some Annotations Missing

**Cause:** Some transcripts don't have corresponding GO/KEGG/Pfam annotations

**Note:** This is normal, using left join preserves all records

### Issue 3: Format Error

**Solutions:**
- Confirm file is tab-separated
- Check if column names are correct
- Remove BOM (Byte Order Mark)

```bash
# Remove BOM
sed -i '1s/^\xEF\xBB\xBF//' file.tsv
```

## Advanced Usage

### Only Keep Records with UniProt Annotations

```python
# Modify code to add filter
result = result[result['accession'] != '']
```

### Customize Output Columns

```python
# Modify desired_cols list
desired_cols = [
    "qseqid", "accession", "SeqID",
    "GOterm", "NameSpace",
    "kegg_annotation",
    "pfam_description"
]
```

### Handle Large Amounts of Annotations

```python
# Use chunk to process large files
for chunk in pd.read_csv(file, sep='\t', chunksize=10000):
    process(chunk)
```

## Verify Output

```bash
# Count total records
wc -l merged_annotations.tsv

# Count records with GO annotations
awk -F'\t' 'NR>1 && $5!=""' merged_annotations.tsv | wc -l

# Count records with Pfam annotations
awk -F'\t' 'NR>1 && $11!=""' merged_annotations.tsv | wc -l

# View null value distribution
for i in $(seq 1 13); do 
    echo -n "Column $i: "; 
    awk -F'\t' -v c=$i 'NR>1 && $c==""' merged_annotations.tsv | wc -l; 
done
```

## Performance Optimization

- For large files, increase chunksize
- Use Cython to accelerate key functions
- Pre-index files
