# Step 5: 合并注释文件 (merge_annotations.py)

## 目的

将多个来源的注释信息(Diamond比对结果、GO、KEGG、KOG、Pfam)整合成一个统一的注释文件，便于后续分析和可视化。

## 脚本功能

1. **读取多个注释来源**: 从不同格式的注释文件读取数据
2. **建立索引映射**: 通过UniProt accession建立转录本ID与功能注释的映射
3. **合并整合**: 将所有注释合并到一条记录中
4. **去重聚合**: 处理一对多的关系(一个转录本对应多个GO term等)

## 使用方法

### 基础用法

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

### 参数说明

| 参数 | 必需 | 说明 | 示例 |
|------|------|------|------|
| `--anno_uniprot_besthit` | ✓ | Diamond最佳比对文件 | `anno_uniprot_besthit.tsv` |
| `--trans_uniprot` | ✓ | UniProt映射文件 | `trans_uniprot.xls` |
| `--trans_go` | ✓ | GO注释文件 | `trans_go.xls` |
| `--trans_kegg` | ✓ | KEGG注释文件 | `trans_kegg.xls` |
| `--trans_kog` | ✓ | KOG注释文件 | `trans_kog.xls` |
| `--trans_pfam` | ✓ | Pfam注释文件 | `trans_pfam.xls` |
| `-o, --output` | ✓ | 输出文件路径 | `merged_annotations.tsv` |
| `--one_row_per_qseqid` | ✗ | 每条查询只输出一行 | Flag |

## 输入文件格式

### anno_uniprot_besthit.tsv

Diamond输出的最佳比对结果，tab分隔:

```
qseqid	accession	entry_name	reviewed	pident	align_len	evalue	bitscore	description
MSTRG.1.1	P12345	ATP synthase	reviewed	95.5	500	1e-100	450.2	ATP synthase subunit alpha
```

### trans_uniprot.xls

转录本到UniProt的映射，tab分隔:

```
SeqID	Accession	Annotation
Msa000001-mRNA-1	sp|P12345|ATP5A1	ATP synthase subunit alpha
Msa000002-mRNA-1	sp|P54369|ATPA	ATP synthase subunit beta
```

### trans_go.xls

GO注释，tab分隔:

```
SeqID	Accession	GOterm	NameSpace	Description
Msa000001-mRNA-1	GO:0015078	ATP synthase activity	molecular_function	Catalyzes the synthesis of ATP
Msa000001-mRNA-1	GO:0015986	ATP synthesis coupled proton transport	biological_process	Process of ATP synthesis
```

### trans_kegg.xls

KEGG通路注释:

```
SeqID	Accession	Annotation
Msa000001-mRNA-1	K02136	ATP synthase
```

### trans_kog.xls

KOG同源簇注释:

```
SeqID	KogID	KogName	KogClassName	KogClassCode
Msa000001-mRNA-1	KOG0266	ATP synthase alpha/beta	Energy production	C
```

### trans_pfam.xls

Pfam结构域注释:

```
SeqID	Accession	HMMProfile	Description
Msa000001-mRNA-1	PF00136	ATP_synt_B	ATP synthase B chain
```

## 输出文件格式

### merged_annotations.tsv

整合后的注释文件，包含以下列:

| 列名 | 描述 | 来源 |
|------|------|------|
| qseqid | 查询序列ID | Diamond结果 |
| accession | UniProt accession | Diamond结果 |
| SeqID | 转录本ID | 映射文件 |
| GOterm | GO术语 | GO注释 |
| NameSpace | GO命名空间 | GO注释 |
| Description | GO描述 | GO注释 |
| kegg_accession | KEGG ID | KEGG注释 |
| kegg_annotation | KEGG注释 | KEGG注释 |
| KogClassName | KOG分类名 | KOG注释 |
| pfam_accession | Pfam ID | Pfam注释 |
| HMMProfile | HMM模型名 | Pfam注释 |
| pfam_description | Pfam描述 | Pfam注释 |

### 输出示例

```
qseqid	accession	SeqID	GOterm	NameSpace	Description	kegg_accession	kegg_annotation	KogClassName	pfam_accession	HMMProfile	pfam_description
MSTRG.1.1	A0A072TI93	Msa0066300-mRNA-1	GO:0016310	biological_process	phosphorylation	K00859	coaE dephospho-CoA kinase	PF01121.25	CoaE	Dephospho-CoA kinase
```

## 处理逻辑

### 1. 读取和标准化

```python
# 读取所有输入文件
anno = pd.read_csv(besthit_file, sep='\t')
trans_uniprot = pd.read_csv(uniprot_file, sep='\t')

# 标准化UniProt accession (去除sp|前缀)
def normalize_core_uniprot(acc):
    parts = acc.split('|')
    if len(parts) >= 2:
        return parts[1]  # 只保留核心accession
    return acc
```

### 2. 建立索引

```python
# 建立 UniProt accession -> 转录本ID 映射
# 一个UniProt可能对应多个转录本
acc_to_seqids = trans_uniprot.groupby('core_acc')['SeqID'].apply(list).to_dict()
```

### 3. 合并注释

```python
# 通过SeqID连接所有注释表
result = base.merge(go_agg, on='SeqID', how='left')
result = result.merge(kegg_agg, on='SeqID', how='left')
result = result.merge(kog_agg, on='SeqID', how='left')
result = result.merge(pfam_agg, on='SeqID', how='left')
```

### 4. 聚合处理

对于一对多关系(如一个蛋白有多个GO term)，使用分号合并:

```
GO:0016310;GO:0006468;GO:0006754
```

## 常见问题

### 问题1: 合并后记录数变少

**原因:** UniProt accession映射不到转录本ID

**解决方案:**
- 检查trans_uniprot.xls中的SeqID是否正确
- 确认格式匹配(区分大小写)

### 问题2: 某些注释缺失

**原因:** 某些转录本没有对应的GO/KEGG/Pfam注释

**说明:** 这是正常的，使用left join保留所有记录

### 问题3: 格式错误

**解决方案:**
- 确认文件是tab分隔
- 检查列名是否正确
- 去除BOM (Byte Order Mark)

```bash
# 去除BOM
sed -i '1s/^\xEF\xBB\xBF//' file.tsv
```

## 高级用法

### 只保留有UniProt注释的记录

```python
# 修改代码，添加过滤
result = result[result['accession'] != '']
```

### 自定义输出列

```python
# 修改desired_cols列表
desired_cols = [
    "qseqid", "accession", "SeqID",
    "GOterm", "NameSpace",
    "kegg_annotation",
    "pfam_description"
]
```

### 处理大量注释

```python
# 使用chunk处理大文件
for chunk in pd.read_csv(file, sep='\t', chunksize=10000):
    process(chunk)
```

## 验证输出

```bash
# 统计总记录数
wc -l merged_annotations.tsv

# 统计有GO注释的记录
awk -F'\t' 'NR>1 && $5!=""' merged_annotations.tsv | wc -l

# 统计有Pfam注释的记录
awk -F'\t' 'NR>1 && $11!=""' merged_annotations.tsv | wc -l

# 查看空值分布
for i in $(seq 1 13); do 
    echo -n "Column $i: "; 
    awk -F'\t' -v c=$i 'NR>1 && $c==""' merged_annotations.tsv | wc -l; 
done
```

## 性能优化

- 对于大文件，增加chunksize
- 使用Cython加速关键函数
- 预先索引文件
