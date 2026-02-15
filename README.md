# Transcriptome Functional Annotation Pipeline

转录组功能注释完整流程，用于从GTF注释文件生成全面的功能注释。

## 概述

本流程生成分子功能注释信息，包括：
- **UniProt/SwissProt最佳比对**: 蛋白质序列比对到SwissProt数据库
- **GO (Gene Ontology)**: 基因本体论注释
- **KEGG Pathway**: 代谢通路注释
- **KOG (KEGG Orthology Groups)**: 同源基因簇注释
- **Pfam Domain**: 蛋白质结构域注释

```
输入GTF → 提取序列 → ORF预测 → Diamond比对 → Pfam注释 → 合并注释
```

## 目录结构

```
annotation_pipeline/
├── scripts/
│   ├── 00_download_databases.sh     # 下载数据库
│   ├── 01_prepare_reference.sh      # 准备参考注释
│   ├── 02_annotation_pipeline.sh    # 主注释流程
│   ├── 03_generate_reference_annotations.sh  # 从GTF生成参考注释
│   └── merge_annotations.py        # 合并注释文件
├── reference/                        # 数据库文件目录
├── docs/
└── run_full_pipeline.sh            # 一键运行完整流程
```

## 安装依赖

### 创建conda环境

```bash
# 创建并激活环境
conda create -n annotation python=3.8
conda activate annotation

# 安装核心软件
conda install -c bioconda diamond transdecoder hmmer bedtools gffread
conda install -c conda-forge pandas

# 安装eggNOG-mapper (可选，用于KOG/GO注释)
pip install eggnog-mapper
```

### 依赖软件说明

| 软件 | 用途 | 安装方式 |
|------|------|----------|
| **Diamond** | 快速蛋白质比对 | `conda install -c bioconda diamond` |
| **TransDecoder** | ORF预测 | `conda install -c bioconda transdecoder` |
| **HMMER/Pfam** | 蛋白质结构域注释 | `conda install -c bioconda hmmer` |
| **gffread** | 从GTF提取序列 | `conda install -c bioconda gffread` |
| **bedtools** | 基因组操作 | `conda install -c bioconda bedtools` |
| **pandas** | 数据处理 | `conda install -c conda-forge pandas` |

## 数据库下载

### 手动下载 (推荐)

1. **UniProt SwissProt**:
   - 下载地址: https://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/complete/
   - 文件: `uniprot_sprot.fasta.gz`
   - 创建Diamond数据库: `diamond makedb --in uniprot_sprot.fasta.gz -d uniprot_sprot.dmnd`

2. **Pfam**:
   - 下载地址: https://ftp.ebi.ac.uk/pub/databases/Pfam/current_release/
   - 文件: `Pfam-A.hmm.gz`
   - 解压后使用: `hmmpress Pfam-A.hmm`

3. **eggNOG** (可选):
   - 使用Python安装: `python -m eggnog_downloader.downloader --data_dir ./eggnog --taxid TAXID`
   - TAXID参考: 人类=9606, 小鼠=10090, 拟南芥=3702, 苜蓿=3880

4. **KEGG**:
   - 需要从 https://www.genome.jp/tools/kaas/ 网页上传序列
   - 或使用本地工具 KofamScan

### 使用脚本自动下载

```bash
bash scripts/00_download_databases.sh ./reference 16
```

参数说明：
- `$1`: 数据库保存目录 (默认: ./reference)
- `$2`: 线程数 (默认: 16)

## 快速开始

### 方式一: 一键运行完整流程

```bash
bash run_full_pipeline.sh \
    /path/to/input.gtf \          # 输入GTF文件
    /path/to/genome.fa \          # 参考基因组FASTA
    /path/to/reference.gtf \       # 参考GTF (可选)
    ./reference \                 # 数据库目录
    ./annotation_results          # 输出目录
```

### 方式二: 分步运行

```bash
# Step 1: 运行注释主流程
cd annotation_results
bash ../scripts/02_annotation_pipeline.sh \
    /path/to/input.gtf \
    /path/to/genome.fa \
    /path/to/reference.gtf \
    ../reference \
    . \
    16

# Step 2: 生成参考注释
bash ../scripts/03_generate_reference_annotations.sh \
    /path/to/reference.gtf \
    reference_transcripts.fa \
    "" \
    Reference \
    16 \
    /path/to/genome.fa

# Step 3: 合并注释
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

## 输入文件格式

### GTF文件格式要求

GTF文件必须包含以下属性:
- `transcript_id`: 转录本ID
- `gene_id`: 基因ID
- `gene_name`: 基因名称 (可选)

示例:
```
chr1    StringTie   transcript  11873   14409   .   +   .   gene_id "MSTRG.1"; transcript_id "MSTRG.1.1"; gene_name "AT1G01020";
```

### 基因组FASTA

标准FASTA格式，支持.gz压缩:
```
>chr1
ATGCGCTAGCTAGCTAGCTAGCTAGCTAGCTA...
>chr2
GCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTA...
```

## 输出文件说明

| 文件名 | 描述 |
|--------|------|
| `transcripts.fa` | 转录本核苷酸序列 |
| `transcripts.transdecoder.pep` | 预测的蛋白质序列 (ORF) |
| `diamond_blastp.outfmt6` | Diamond蛋白质比对结果 |
| `TrinotatePFAM.out` | Pfam结构域注释 |
| `anno_uniprot_besthit.tsv` | UniProt最佳比对 |
| `merged_annotations.tsv` | 最终整合注释 |

### merged_annotations.tsv 输出列说明

| 列名 | 描述 | 示例 |
|------|------|------|
| qseqid | 查询序列ID | ONT.2.1 |
| accession | UniProt accession | A0A072TI93 |
| SeqID | 转录本ID | Msa0066300-mRNA-1 |
| GOterm | GO术语 | GO:0016310 |
| NameSpace | GO命名空间 | biological_process |
| Description | 描述 | phosphorylation |
| kegg_accession | KEGG accession | K00859 |
| kegg_annotation | KEGG注释 | coaE dephospho-CoA kinase |
| KogClassName | KOG分类名 | Chaperone HSP104 |
| pfam_accession | Pfam ID | PF01121.25 |
| HMMProfile | HMM模型名 | CoaE |
| pfam_description | Pfam描述 | Dephospho-CoA kinase |

## 脚本详细说明

### 00_download_databases.sh

下载并准备所需的数据库文件。

**参数:**
| 参数 | 默认值 | 说明 |
|------|--------|------|
| `$1` | ./reference | 数据库保存目录 |
| `$2` | 16 | 并行线程数 |

**输出文件:**
- `uniprot_sprot.fasta.gz`: SwissProt序列
- `uniprot_sprot.dmnd`: Diamond数据库
- `Pfam-A.hmm`: Pfam HMM模型

**注意事项:**
- 首次下载需要较大空间 (约2GB)
- Diamond建库可能需要较长时间
- KEGG需要手动从网页下载

---

### 02_annotation_pipeline.sh

主注释流程脚本。

**参数:**
| 参数 | 说明 | 示例 |
|------|------|------|
| `$1` | 输入GTF文件 | `/path/to/stringtie.gtf` |
| `$2` | 参考基因组FASTA | `/path/to/genome.fa` |
| `$3` | 参考GTF (可选) | `/path/to/ref.gtf` |
| `$4` | 数据库目录 | `./reference` |
| `$5` | 输出目录 | `./annotation_results` |
| `$6` | 线程数 | 16 |

**步骤详解:**

#### Step 1: 提取转录本序列
```bash
gffread input.gtf -g genome.fa -w transcripts.fa
```
- 使用gffread从GTF和基因组提取转录本核苷酸序列
- 确保基因组FASTA索引存在 (.fai)

#### Step 2: ORF预测
```bash
TransDecoder.LongOrfs -t transcripts.fa -m 100
TransDecoder.Predict -t transcripts.fa
```
- `-m 100`: 最小ORF长度100氨基酸
- 输出: `transcripts.transdecoder.pep`

**注意**: 仅保留最长的ORF，可能丢失部分转录本

#### Step 3: Diamond比对
```bash
diamond blastp --db uniprot_sprot.dmnd --query transcripts.transdecoder.pep \
    --outfmt 6 --max-target-seqs 1 --evalue 1e-5 --threads 16
```
- `--max-target-seqs 1`: 只保留最佳比对
- `--evalue 1e-5`: E-value阈值
- 可选: 添加物种特异性数据库提高注释率

**Diamond参数调优:**
| 参数 | 默认值 | 调整建议 |
|------|--------|----------|
| `--evalue` | 1e-5 | 严格注释用1e-10 |
| `--max-target-seqs` | 1 | 保留更多比对设为5 |
| `--id` | 无 | 最低一致性，如--id 50 |
| `--query-cover` | 无 | 最低覆盖度，如--query-cover 70 |

#### Step 4: Pfam注释
```bash
hmmscan --cpu 16 --domtblout TrinotatePFAM.out Pfam-A.hmm proteins.pep
```
- 使用HMMER的hmmscan进行蛋白质结构域注释
- 输出格式: domain table out

**注意事项:**
- Pfam数据库较大，耗时较长
- 可使用`--E 1e-5`设置E-value阈值

#### Step 5: 生成最佳比对
- 从Diamond结果中提取每个转录本的最佳UniProt匹配
- 生成`anno_uniprot_besthit.tsv`

---

### 03_generate_reference_annotations.sh

从参考GTF生成注释文件，用于后续合并。

**参数:**
| 参数 | 说明 |
|------|------|
| `$1` | 输入GTF文件 |
| `$2` | 转录本FASTA输出名 |
| `$3` | 参考蛋白FASTA (可选) |
| `$4` | 输出前缀 |
| `$5` | 线程数 |
| `$6` | 基因组FASTA |

**输出文件:**
- `reference_trans_uniprot.xls`
- `reference_trans_go.xls`
- `reference_trans_kegg.xls`
- `reference_trans_kog.xls`
- `reference_trans_pfam.xls`

**注意事项:**
- GO/KEGG/KOG需要额外工具生成
- 可以使用placeholder文件跳过

---

### merge_annotations.py

整合多个注释来源，生成最终注释文件。

**参数:**
| 参数 | 必需 | 说明 |
|------|------|------|
| `--anno_uniprot_besthit` | ✓ | Diamond最佳比对结果 |
| `--trans_uniprot` | ✓ | 转录本-Uniprot映射 |
| `--trans_go` | ✓ | GO注释文件 |
| `--trans_kegg` | ✓ | KEGG注释文件 |
| `--trans_kog` | ✓ | KOG注释文件 |
| `--trans_pfam` | ✓ | Pfam注释文件 |
| `-o/--output` | ✓ | 输出文件路径 |
| `--one_row_per_qseqid` | ✗ | 每条查询只输出一行 |

**使用方法:**
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

## 参考注释文件格式

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

## 常见问题

### 1. 注释率低怎么办？

**原因分析:**
- 转录本太短 (无ORF)
- 新物种/特有基因
- ORF预测失败

**解决方案:**
- 添加物种特异性数据库
- 降低Diamond E-value阈值
- 使用Trinity进行从头注释
- 检查ORF预测是否正确

### 2. Diamond比对时间过长

**解决方案:**
- 增加线程数
- 使用--ultra-sensitive参数
- 预先建立数据库索引

### 3. Pfam注释失败

**检查项:**
- HMM数据库是否正确解压
- hmmpress是否运行
- 蛋白质序列格式是否正确

### 4. 内存不足

**解决方案:**
- 减小批量处理大小
- 使用--block-size参数
- 增加swap空间

### 5. GTF格式错误

**常见错误:**
- 缺少必须的属性字段
- 染色体名称不匹配
- 坐标超出范围

**检查方法:**
```bash
# 验证GTF格式
gffread -E input.gtf -o /dev/null 2>&1

# 查看转录本数量
grep -c 'transcript' input.gtf
```

## 物种特异性注释

### 苜蓿 (Medicago sativa)

1. 下载参考基因组
2. 使用StringTie进行注释
3. 运行本流程
4. 使用Medicago truncatula (TAXID: 3880) 数据库

### 拟南芥 (Arabidopsis thaliana)

- TAXID: 3702
- 推荐数据库: TAIR
- 可使用Araport11注释

### 水稻 (Oryza sativa)

- TAXID: 4530
- 推荐使用MSU注释

## 性能优化

### 并行化

```bash
# 使用更多线程
THREADS=32 bash scripts/02_annotation_pipeline.sh ...

# 使用GNU parallel进行批量处理
parallel -j 8 diamond blastp ::: *.pep
```

### 内存优化

```bash
# Diamond分块处理
diamond blastp --db db.dmnd --query query.fa --out out.tsv \
    --block-size 10 --threads 16
```

## 引用

如果使用本流程，请引用以下工具:

- **Diamond**: Buchfink B, Xie Y, Huson DH. Fast and sensitive protein alignment using DIAMOND. Nature Methods. 2015
- **TransDecoder**: Haas BJ, et al. TransDecoder: finding coding regions in genome sequences. 2013
- **HMMER**: Finn RD, Clements J, Eddy SR. HMMER web server: interactive sequence similarity searching. Nucleic Acids Research. 2011

## 许可证

MIT License

## 联系方式

问题反馈: https://github.com/IceBear321/Transcriptome_Functional_Annotation/issues
