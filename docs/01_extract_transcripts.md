# Step 1: 提取转录本序列

## 目的

从GTF注释文件和参考基因组FASTA文件中提取转录本的核苷酸序列。这是整个注释流程的基础，因为后续的ORF预测和蛋白质比对都依赖于转录本序列。

## 使用工具

**gffread**: GFFutils工具包的一部分，用于从GTF/GFF提取序列。

## 命令

```bash
gffread input.gtf -g genome.fa -w transcripts.fa
```

## 参数说明

| 参数 | 说明 | 示例 |
|------|------|------|
| `input.gtf` | 输入GTF文件 | `stringtie_long.hq.gtf` |
| `-g genome.fa` | 参考基因组FASTA | `/path/to/genome.fa` |
| `-w transcripts.fa` | 输出转录本FASTA | `transcripts.fa` |

## 其他有用参数

```bash
# 提取CDS序列
gffread input.gtf -g genome.fa -x cds.fa

# 提取蛋白质序列 (需要GTF中有CDS注释)
gffread input.gtf -g genome.fa -y protein.fa

# 只保留转录本
gffread input.gtf -g genome.fa -w transcripts.fa -t transcript

# 添加基因组坐标到序列ID
gffread input.gtf -g genome.fa -w transcripts.fa -W
```

## 输入文件要求

### GTF格式要求

1. 必须包含`transcript`类型的行
2. 必须有`transcript_id`属性
3. 基因组FASTA的染色体名称必须与GTF中的染色体名称完全匹配

示例GTF行:
```
chr1    StringTie   transcript  11873   14409   .   +   .   gene_id "MSTRG.1"; transcript_id "MSTRG.1.1";
```

### 基因组FASTA格式

标准FASTA格式，染色体名称必须与GTF匹配:
```
>chr1
ATGCGCTAGCTAGCTAGCTAGCTAGCTAGCTA...
>chr2
GCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTA...
```

## 输出文件格式

FASTA格式，每条序列的header包含转录本ID:

```
>MSTRG.1.1
ATGCGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTA...
>MSTRG.2.1
GCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTA...
```

## 常见问题

### 问题1: 染色体名称不匹配

**错误信息:**
```
Error: chromosome 'chr1' not found in genome file!
```

**解决方案:**
检查GTF和基因组FASTA中的染色体命名是否一致。可能需要统一命名方式:
```bash
# 统一添加chr前缀
sed -i 's/^>/>chr/' genome.fa

# 或去掉chr前缀
sed -i 's/^chr//' genome.fa
```

### 问题2: GTF中缺少转录本

**检查方法:**
```bash
# 统计GTF中转录本数量
grep -c 'transcript' input.gtf

# 检查是否有正确的属性
grep 'transcript' input.gtf | head -5
```

### 问题3: 提取的序列数量少于预期

可能原因:
- GTF中部分转录本没有有效的坐标范围
- 基因组版本不匹配

**解决方案:**
```bash
# 验证GTF文件
gffread -E input.gtf -o /dev/null 2>&1

# 检查GTF转录本是否完整
gffread input.gtf -g genome.fa -w /dev/null -v
```

## 性能提示

- gffread支持多线程，但主要瓶颈在文件IO
- 对于大型基因组，建议提前创建faidx索引:
```bash
samtools faidx genome.fa
```
