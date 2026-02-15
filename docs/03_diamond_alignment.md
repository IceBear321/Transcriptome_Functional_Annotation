# Step 3: Diamond蛋白质比对

## 目的

将预测的蛋白质序列比对到UniProt SwissProt数据库，获取最佳匹配，用于推断蛋白质功能和获取GO/KEGG注释。

## 使用工具

**Diamond**: 比BLAST快数千倍的蛋白质比对工具，适合大规模注释任务。

## 命令

```bash
# 蛋白质vs蛋白质比对 (blastp)
diamond blastp \
    --db /path/to/uniprot_sprot.dmnd \
    --query transcripts.transdecoder.pep \
    --outfmt 6 \
    --max-target-seqs 1 \
    --evalue 1e-5 \
    --threads 16 \
    --out diamond_blastp.outfmt6

# 核苷酸vs蛋白质比对 (blastx) - 可选
diamond blastx \
    --db /path/to/uniprot_sprot.dmnd \
    --query transcripts.fa \
    --outfmt 6 \
    --max-target-seqs 1 \
    --evalue 1e-5 \
    --threads 16 \
    --out diamond_blastx.outfmt6
```

## 参数详解

### 常用参数

| 参数 | 说明 | 建议值 |
|------|------|--------|
| `--db` | Diamond数据库路径 | (必需) |
| `--query` | 查询序列文件 | (必需) |
| `--out` | 输出文件 | (必需) |
| `--outfmt` | 输出格式 | 6 (BLAST tabular) |
| `--max-target-seqs` | 最大目标序列数 | 1 |
| `--evalue` | E-value阈值 | 1e-5 |
| `--threads` | 线程数 | 16 |
| `--id` | 最小一致性 | 可选 |
| `--query-cover` | 最小查询覆盖度 | 可选 |

### 输出格式 (--outfmt 6)

标准BLAST表格格式，包含12列:

| 列 | 说明 |
|----|------|
| 1 | 查询序列ID (qseqid) |
| 2 | 目标序列ID (sseqid) |
| 3 | 一致性百分比 (pident) |
| 4 | 比对长度 (length) |
| 5 | 不匹配数 (mismatch) |
| 6 | 缺失数 (gapopen) |
| 7 | 查询起始 (qstart) |
| 8 | 查询结束 (qend) |
| 9 | 目标起始 (sstart) |
| 10 | 目标结束 (send) |
| 11 | E-value |
| 12 | Bit score |

## 数据库准备

### 创建Diamond数据库

```bash
# 从FASTA创建数据库
diamond makedb --in uniprot_sprot.fasta.gz -d uniprot_sprot.dmnd

# 可选: 添加taxid信息
diamond makedb --in uniprot_sprot.fasta.gz -d uniprot_sprot.dmnd --taxonmap prot.accession2taxid.gz
```

### 推荐数据库

1. **SwissProt** (推荐):
   - 高质量手工注释
   - 约560,000条序列
   - 下载: `uniprot_sprot.fasta.gz`

2. **UniRef90**:
   - 聚类后非冗余
   - 约27,000,000条序列
   - 适合远缘物种

3. **物种特异性数据库**:
   - 可从NCBI构建
   - 提高注释率

## 参数调优

### 严格注释 (减少假阳性)
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

### 宽松注释 (捕获更多同源物)
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

### 快速模式
```bash
diamond blastp \
    --db db.dmnd \
    --query proteins.pep \
    --outfmt 6 \
    --block-size 10 \
    --threads 16 \
    --out result.tsv
```

## 输出文件处理

### 提取最佳比对

```python
import pandas as pd

# 读取diamond结果
df = pd.read_csv('diamond_blastp.outfmt6', 
                 sep='\t',
                 names=['qseqid','sseqid','pident','length','mismatch',
                        'gapopen','qstart','qend','sstart','send','evalue','bitscore'])

# 取每条查询的最佳比对
best = df.sort_values('bitscore', ascending=False).groupby('qseqid').first().reset_index()
best.to_csv('best_hits.tsv', sep='\t', index=False)
```

## 常见问题

### 问题1: 比对率太低

**可能原因:**
1. 物种太新/特异
2. 蛋白质序列太短
3. ORF预测失败

**解决方案:**
- 使用物种相关数据库
- 检查ORF预测结果
- 降低E-value阈值

### 问题2: 内存不足

**解决方案:**
```bash
# 使用分块处理
diamond blastp --db db.dmnd --query proteins.pep --block-size 5 --out result.tsv

# 或使用--index-chunks
diamond --index-chunks 4
```

### 问题3: 比对速度太慢

**解决方案:**
- 增加线程数
- 使用--ultra-sensitive (反而可能更快)
- 减小查询文件大小

### 问题4: 数据库太大

**解决方案:**
```bash
# 提取物种子集
diamond get_species_taxids -d db.dmnd --taxonlist 3702,3880,9606 > species.dmnd

# 或提取特定分类
diamond subsetdb -d uniprot.dmnd -o plant.dmnd --taxon 33090  # Viridiplantae
```

## 性能基准

| 数据库 | 序列数 | 索引大小 | 10K查询耗时 |
|--------|--------|----------|-------------|
| SwissProt | 560K | 2.5GB | ~30秒 |
| UniRef90 | 27M | 45GB | ~10分钟 |
| NR | 250M | 400GB | ~1小时 |

## 验证结果

```bash
# 统计比对成功率
awk '{print $1}' diamond_blastp.outfmt6 | sort -u | wc -l

# 统计唯一比对数
awk '$11<1e-10' diamond_blastp.outfmt6 | wc -l

# 查看一致性分布
awk '{print $3}' diamond_blastp.outfmt6 | sort -n | uniq -c | tail -20
```
