# 故障排除指南

本文档列出使用转录组功能注释流程时可能遇到的常见问题及其解决方案。

## 目录

1. [数据准备问题](#数据准备问题)
2. [安装问题](#安装问题)
3. [运行问题](#运行问题)
4. [输出问题](#输出问题)
5. [性能问题](#性能问题)

---

## 数据准备问题

### 问题1: GTF格式不正确

**症状:**
```
Error: gffread: Cannot get coordinates from transcript line
```

**检查方法:**
```bash
# 检查GTF是否有正确的转录本行
grep 'transcript' input.gtf | head -3

# 验证GTF格式
gffread -E input.gtf -o /dev/null 2>&1
```

**解决方案:**
- 确保GTF包含`transcript`类型的行
- 确保每行有9列
- 确保包含`transcript_id`属性

### 问题2: 基因组FASTA索引缺失

**症状:**
```
Error: Could not locate fasta index file for genome.fa
```

**解决方案:**
```bash
# 创建faidx索引
samtools faidx genome.fa

# 或使用gffread创建
gffread -E input.gtf -g genome.fa -o /dev/null
```

### 问题3: 染色体名称不匹配

**症状:**
```
Error: chromosome 'chr1' not found in genome file!
```

**检查:**
```bash
# 查看GTF中的染色体
cut -f1 input.gtf | sort -u | head -10

# 查看基因组FASTA中的染色体
grep '^>' genome.fa | head -10
```

**解决方案:**
```bash
# 统一添加chr前缀
sed -i 's/^>/>chr/' genome.fa
sed -i 's/\tchr/\t/g' input.gtf

# 或去掉chr前缀
sed -i 's/^chr//' genome.fa
```

---

## 安装问题

### 问题4: Conda环境创建失败

**症状:**
```
CondaHTTPError: HTTP error 404
```

**解决方案:**
```bash
# 清除缓存
conda clean --all

# 换源
conda config --add channels conda-forge
conda config --add channels bioconda
```

### 问题5: Diamond数据库创建失败

**症状:**
```
Error: Error opening sequence file
```

**解决方案:**
```bash
# 检查文件完整性
file uniprot_sprot.fasta.gz

# 解压后检查
gunzip -c uniprot_sprot.fasta.gz | head -10

# 重新下载
wget -c ftp://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/complete/uniprot_sprot.fasta.gz
```

### 问题6: TransDecoder找不到

**症状:**
```
Command 'TransDecoder.LongOrfs' not found
```

**解决方案:**
```bash
# 激活conda环境
conda activate annotation

# 或重新安装
conda install -c bioconda transdecoder -y

# 确认安装
which TransDecoder.LongOrfs
```

---

## 运行问题

### 问题7: ORF预测失败

**症状:**
```
No ORFs found in transcripts
```

**可能原因:**
1. 转录本太短
2. 序列不是标准遗传密码
3. GTF提取的序列有误

**解决方案:**
```bash
# 检查转录本长度分布
awk '/^>/{id=$0; next} {print length($0)}' transcripts.fa | sort -n | tail -10

# 降低最小ORF长度
TransDecoder.LongOrfs -t transcripts.fa -m 30

# 检查序列质量
head -20 transcripts.fa
```

### 问题8: Diamond比对无结果

**症状:**
```
0 hits found
```

**检查步骤:**
```bash
# 检查蛋白质文件
grep -c '^>' proteins.pep

# 检查数据库
diamond makedb --in proteins.pep --db test --validate

# 检查序列格式
head -5 proteins.pep
```

**解决方案:**
- 降低E-value阈值
- 检查ORF预测是否成功
- 使用物种相关数据库

### 问题9: Pfam注释失败

**症状:**
```
Error: hmmscan crashed
```

**解决方案:**
```bash
# 检查Pfam数据库
hmmstat Pfam-A.hmm

# 重新创建索引
hmmpress Pfam-A.hmm

# 检查蛋白质文件格式
head -3 proteins.pep
```

---

## 输出问题

### 问题10: 合并注释失败

**症状:**
```
KeyError: 'SeqID'
```

**检查:**
```bash
# 检查列名
head -1 anno_uniprot_besthit.tsv
head -1 trans_uniprot.xls
```

**解决方案:**
- 确认列名匹配
- 检查文件分隔符(必须是tab)
- 去除BOM

```bash
# 检查分隔符
file merged_annotations.tsv

# 去除BOM
sed -i '1s/^\xEF\xBB\xBF//' file.tsv
```

### 问题11: 注释率低

**症状:**
```
只有20%的转录本有功能注释
```

**分析步骤:**
```bash
# 统计各步骤成功率
echo "转录本: $(grep -c '^>' transcripts.fa)"
echo "蛋白: $(grep -c '^>' proteins.pep)"
echo "Diamond比对: $(cut -f1 diamond.out | sort -u | wc -l)"
echo "Pfam注释: $(cut -f3 TrinotatePFAM.out | sort -u | wc -l)"
```

**提高注释率的方法:**
1. 添加物种特异性数据库
2. 降低E-value阈值
3. 使用更多数据库(UniRef90, NR)
4. 使用InterProScan补充注释

### 问题12: 输出文件格式错误

**症状:**
```
Excel打开后格式混乱
```

**说明:** 这是Excel对TSV的处理问题，不是文件本身错误

**解决方案:**
```bash
# 转换为CSV
awk -F'\t' 'BEGIN{OFS=","} {$1=$1; print}' merged_annotations.tsv > merged_annotations.csv

# 或在Excel中导入时选择正确的分隔符
```

---

## 性能问题

### 问题13: 运行时间过长

**症状:**
```
流程运行超过24小时
```

**优化方案:**

1. **增加线程数**
```bash
THREADS=32 bash run_full_pipeline.sh
```

2. **减少查询文件大小**
```bash
# 过滤短序列
awk '/^>/{keep=length($0)>500} keep' proteins.pep > proteins_filtered.pep
```

3. **使用快速模式**
```bash
diamond blastp --ultra-sensitive --db db.dmnd --query proteins.pep
```

### 问题14: 内存不足

**症状:**
```
Killed (out of memory)
```

**解决方案:**

1. **减少线程数**
```bash
THREADS=4 bash scripts/02_annotation_pipeline.sh
```

2. **分块处理**
```bash
# Diamond分块
diamond blastp --block-size 5 --db db.dmnd --query proteins.pep

# HMMER分块
hmmscan --max -E 1e-5 Pfam-A.hmm proteins.pep
```

3. **增加swap**
```bash
# 查看当前内存
free -h

# 增加swap (如需4GB)
sudo dd if=/dev/zero of=/swapfile bs=1G count=4
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### 问题15: 磁盘空间不足

**症状:**
```
No space left on device
```

**解决方案:**
```bash
# 清理临时文件
rm -rf tmp/

# 清理conda缓存
conda clean -a

# 使用更小的数据库
# 如只用SwissProt而非NR
```

---

## 调试技巧

### 启用调试模式

```bash
# 在脚本开头添加
set -x  # 打印执行的命令

# 或使用bash -x
bash -x run_full_pipeline.sh
```

### 查看中间结果

```bash
# 检查每个步骤的输出
ls -lh annotation_results/

# 查看日志
tail -50 pfam.log
tail -50 diamond.log
```

### 测试单个样本

```bash
# 提取少量测试数据
head -100 input.gtf > test.gtf
head -100 genome.fa > test.fa

# 运行测试
bash run_full_pipeline.sh test.gtf test.fa
```

---

## 获取帮助

如果以上方案都不能解决问题:

1. 检查日志文件中的详细错误信息
2. 确认所有依赖软件版本
3. 搜索类似问题: https://github.com/IceBear321/Transcriptome_Functional_Annotation/issues
4. 提issue时附上:
   - 错误信息完整内容
   - 使用的命令
   - 系统环境 (uname -a)
   - 软件版本 (conda list)
