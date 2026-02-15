# Step 2: ORF预测 (TransDecoder)

## 目的

从转录本核苷酸序列预测开放阅读框(Open Reading Frame)，生成候选蛋白质序列。这是将转录组数据转化为蛋白质水平进行功能注释的关键步骤。

## 使用工具

**TransDecoder**: 从基因组或转录组数据中识别编码区域的工具。

## 命令

```bash
# Step 1: 识别所有长ORF
TransDecoder.LongOrfs -t transcripts.fa -m 100

# Step 2: 预测编码区域
TransDecoder.Predict -t transcripts.fa
```

## 参数说明

### TransDecoder.LongOrfs

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `-t` | (必需) | 输入转录本FASTA |
| `-m` | 100 | 最小ORF长度(氨基酸) |
| `-S` | false | 只处理反义链 |
| `-g` | false | 使用GMAP比对结果 |

### TransDecoder.Predict

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `-t` | (必需) | 输入转录本FASTA |
| `--no_refine_starts` | false | 不优化起始密码子 |
| `-m` | 100 | 最小蛋白质长度 |
| `--single_best_only` | false | 只保留最佳ORF |

## 工作原理

1. **LongOrfs阶段**: 扫描所有6个阅读框(3个正向+3个反向)，识别长度>=100氨基酸的ORF
2. **Predict阶段**: 使用以下标准选择最佳ORF:
   - 对数似然评分
   - 与已知蛋白质数据库比对得分
   - 蛋白质长度
   - 编码评分

## 输出文件

| 文件 | 描述 |
|------|------|
| `transcripts.fa.transdecoder.pep` | 预测的蛋白质序列 |
| `transcripts.fa.transdecoder.cds` | CDS核苷酸序列 |
| `transcripts.fa.transdecoder.gff3` | GFF3格式注释 |
| `transcripts.fa.transdecoder.bed` | BED格式位置 |

## 蛋白质序列命名

TransDecoder生成的蛋白质ID格式:
```
>TU00001|pilg1|m.1
MVLSPADKTNVKAAWGKVGAHAGEYGAEALERMFLSFPTTKTYFPHFDLSH...
```

格式说明:
- `TU00001`: 转录本ID
- `pilg1`: 基因名(如有)
- `m.1`: 蛋白序号(.p1, .p2等表示多个ORF)

## 常见问题

### 问题1: 预测的蛋白质数量太少

**原因分析:**
- 转录本太短
- 最小长度阈值太高
- 很多转录本是非编码RNA

**解决方案:**
```bash
# 降低最小长度阈值
TransDecoder.LongOrfs -t transcripts.fa -m 50
TransDecoder.Predict -t transcripts.fa -m 50
```

### 问题2: 蛋白质命名与后续流程不匹配

**问题:** TransDecoder输出的蛋白质ID带有.p后缀，后续处理时需要去除

**解决方案:**
```bash
# 去除.p后缀
sed 's/\.p[0-9]*//g' transcripts.transdecoder.pep > proteins_clean.pep
```

### 问题3: 如何使用已知蛋白提高预测

**方法1**: 使用diamond比对结果指导预测
```bash
# 先运行diamond
diamond blastx -d uniprot.dmnd -q transcripts.fa -o diamond.out

# 使用比对结果
TransDecoder.Predict -t transcripts.fa --retain_diamond_hits diamond.out
```

**方法2**: 使用GMAP比对结果
```bash
# 先用GMAP比对到参考蛋白
gmmap -d proteins.fa -t transcripts.fa -o gmap.gff

# 使用比对结果
TransDecoder.LongOrfs -t transcripts.fa -g gmap.gff
TransDecoder.Predict -t transcripts.fa
```

### 问题4: 预测的ORF包含终止密码子*

**说明:** TransDecoder输出中*表示终止密码子位置

**处理方法:**
```bash
# 去除终止密码子标记
sed 's/\*$//' transcripts.transdecoder.pep > proteins.pep
```

## 参数调优建议

### 对于高质量转录组
```bash
TransDecoder.LongOrfs -t transcripts.fa -m 100
TransDecoder.Predict -t transcripts.fa -m 100 --single_best_only
```

### 对于低质量/新物种转录组
```bash
# 保留更多候选ORF
TransDecoder.LongOrfs -t transcripts.fa -m 50
TransDecoder.Predict -t transcripts.fa -m 50
```

### 捕获所有可能ORF
```bash
# 不做选择，保留所有
TransDecoder.LongOrfs -t transcripts.fa -m 30
TransDecoder.Predict -t transcripts.fa -m 30
```

## 与其他工具比较

| 工具 | 优点 | 缺点 |
|------|------|------|
| TransDecoder | 专为转录组设计 | 可能预测过长ORF |
| ORFfinder | NCBI官方工具 | 速度慢 |
| EMBOSS getorf | 速度快 | 阈值设置复杂 |

## 验证输出

```bash
# 统计预测的蛋白数量
grep -c '^>' transcripts.transdecoder.pep

# 查看长度分布
awk '/^>/{id=$0; next} {print length($0)}' transcripts.transdecoder.pep | sort -n | uniq -c | tail -20
```
