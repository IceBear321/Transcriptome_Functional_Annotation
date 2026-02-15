# Step 4: Pfam蛋白质结构域注释

## 目的

使用Pfam数据库对预测的蛋白质进行结构域注释，识别蛋白质家族和保守区域，为功能注释提供额外信息。

## 使用工具

**HMMER (hmmscan)**: 使用隐马尔可夫模型(HMM)进行蛋白质结构域比对。

## 命令

```bash
hmmscan --cpu 16 \
    --domtblout TrinotatePFAM.out \
    /path/to/Pfam-A.hmm \
    transcripts.transdecoder.pep > pfam.log
```

## 参数说明

| 参数 | 说明 | 建议值 |
|------|------|--------|
| `--cpu` | 并行线程数 | 16 |
| `--domtblout` | domain table输出文件 | (必需) |
| `-E` | 全局E-value阈值 | 1e-5 |
| `--domE` | domain E-value阈值 | 1e-5 |
| `--domT` | domain bitscore阈值 | 可选 |

## 输出格式

### Domain Table格式

| 列 | 说明 |
|----|------|
| 1 | 目标名称 (Pfam ID) |
| 2 | 目标.accession |
| 3 | 查询名称 |
| 4 | 查询.accession |
| 5 | 全局E-value |
| 6 | 全局bitscore |
| 7 | 全局覆盖率 |
| 8 | 序列数 |
| 9 | 域名数 |
| 10 | domain E-value |
| 11 | domain bitscore |
| 12 | domain覆盖率 |
| 13-14 | 域在查询中的位置 |
| 15-16 | 域在HMM中的位置 |
| 17 | 氨基酸 |
| 18-22 | 描述 |

## 数据库准备

### 下载Pfam数据库

```bash
# 方法1: 从EBI下载
wget -O Pfam-A.hmm.gz \
    ftp://ftp.ebi.ac.uk/pub/databases/Pfam/current_release/Pfam-A.hmm.gz
gunzip Pfam-A.hmm.gz

# 方法2: 使用conda
conda install -c bioconda hmmer
```

### 创建HMM索引

```bash
# 压缩数据库 (必需)
hmmpress Pfam-A.hmm

# 验证
hmmstat Pfam-A.hmm
```

## 参数调优

### 严格注释
```bash
hmmscan --cpu 16 \
    --domtblout strict_pfam.out \
    -E 1e-10 --domE 1e-10 \
    Pfam-A.hmm proteins.pep
```

### 宽松注释 (捕获更多)
```bash
hmmscan --cpu 16 \
    --domtblout loose_pfam.out \
    -E 1e-3 --domE 1e-3 \
    Pfam-A.hmm proteins.pep
```

### 只保留高置信度
```bash
# bitscore > 20
hmmscan --cpu 16 \
    --domtblout highconf_pfam.out \
    --domT 20 \
    Pfam-A.hmm proteins.pep
```

## 处理Pfam输出

### 提取最佳domain匹配

```python
import pandas as pd

# 读取domain table
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

# 对每个查询取最佳匹配
best = df.sort_values('bitscore', ascending=False).groupby('query_id').first().reset_index()
best.to_csv('pfam_best.tsv', sep='\t', index=False)
```

## 常见问题

### 问题1: 注释率低

**可能原因:**
1. 蛋白质太短
2. 物种特异蛋白
3. 数据库版本旧

**解决方案:**
- 检查蛋白质长度分布
- 更新Pfam数据库
- 使用InterProScan补充

### 问题2: 运行时间过长

**解决方案:**
```bash
# 增加线程
hmmscan --cpu 32 ...

# 使用hmmsearch (针对单序列)
hmmsearch --cpu 16 Pfam-A.hmm protein.pep
```

### 问题3: 内存不足

**解决方案:**
```bash
# 使用--max size限制
hmmscan --cpu 16 --max Pfam-A.hmm proteins.pep
```

## Pfam ID格式说明

- **PFxxxxx**: Pfam家族ID (如PF00001)
- **PFxxxxx_xx**: 同源家族 (clan)

### 常用Pfam家族示例

| Pfam ID | 名称 | 功能 |
|---------|------|------|
| PF00004 | AAA | ATP酶家族 |
| PF00069 | PKinase | 蛋白激酶 |
| PF00118 | Cpn60_TCP1 | 分子伴侣 |
| PF00533 | BRCT | DNA修复 |
| PF07679 | I-set | 免疫球蛋白 |

## 验证结果

```bash
# 统计有多少蛋白有Pfam注释
awk '{print $3}' TrinotatePFAM.out | sort -u | wc -l

# 查看最常见的Pfam
awk '!/^#/{print $1}' TrinotatePFAM.out | sort | uniq -c | sort -rn | head -20

# 查看E-value分布
awk '!/^#/{print $10}' TrinotatePFAM.out | awk '{if($1<1e-10) print "high"; else if($1<1e-5) print "med"; else print "low"}' | sort | uniq -c
```

## 与其他工具比较

| 工具 | 优点 | 数据库 |
|------|------|--------|
| HMMER/Pfam | 权威，注释准确 | Pfam |
| InterProScan | 综合注释 | 多数据库 |
| CDD/NCBI | 保守域 | CDD |
| SMART | 信号通路 | SMART |
