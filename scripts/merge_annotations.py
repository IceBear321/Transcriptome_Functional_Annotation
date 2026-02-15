#!/usr/bin/env python3
"""
merge_annotations.py - Merge transcriptome annotations

This script integrates multiple annotation sources:
- UniProt/SwissProt best hits
- GO annotations
- KEGG pathway annotations  
- KOG ortholog annotations
- Pfam domain annotations

Output format similar to merged_annotations_qseqid_level.tsv
"""

import argparse
import sys
import pandas as pd
from pathlib import Path

def read_tsv(path):
    """Read TSV file, return DataFrame with empty strings for NaN"""
    return pd.read_csv(path, sep="\t", dtype=str).fillna("")

def normalize_core_uniprot(acc):
    """
    Convert strings like 'sp|Q9XYZ1|NAME' or 'tr|A0A000|NAME' to the core accession.
    """
    if not isinstance(acc, str):
        return ""
    acc = acc.strip()
    parts = acc.split("|")
    if len(parts) >= 2:
        return parts[1].strip()
    return acc

def semijoin_unique(series):
    """Deduplicate while preserving order, join with semicolon"""
    vals = [str(x).strip() for x in series.tolist()]
    vals = [v for v in vals if v != "" and v.lower() != "nan"]
    seen = set()
    out = []
    for v in vals:
        if v not in seen:
            seen.add(v)
            out.append(v)
    return ";".join(out)

def build_seqid_index(uniprot_df):
    """Build mapping from core uniprot accession -> list of SeqID(s)"""
    df = uniprot_df.copy()
    df["core_acc"] = df["Accession"].apply(normalize_core_uniprot)
    grouped = df.groupby("core_acc")["SeqID"].apply(list)
    return grouped.to_dict()

def aggregate_by_seqid(df, agg_map):
    """Group by SeqID and aggregate specified columns"""
    if df.empty:
        cols = ["SeqID"] + list(agg_map.keys())
        return pd.DataFrame(columns=cols)
    
    agg_funcs = {}
    for col, how in agg_map.items():
        agg_funcs[col] = semijoin_unique
    
    grouped = df.groupby("SeqID", as_index=False).agg(agg_funcs)
    return grouped

def main():
    ap = argparse.ArgumentParser(
        description="Merge transcriptome annotation tables using UniProt accession -> SeqID -> GO/KEGG/KOG/PFAM"
    )
    ap.add_argument("--anno_uniprot_besthit", required=True, 
                    help="Best hit annotation file (from diamond)")
    ap.add_argument("--trans_uniprot", required=True, 
                    help="Transcript to UniProt mapping (e.g., Medicago_Sativa.trans_uniprot.xls)")
    ap.add_argument("--trans_go", required=True, 
                    help="GO annotation file (e.g., Medicago_Sativa.trans_go.xls)")
    ap.add_argument("--trans_kegg", required=True, 
                    help="KEGG annotation file")
    ap.add_argument("--trans_kog", required=True, 
                    help="KOG annotation file")
    ap.add_argument("--trans_pfam", required=True, 
                    help="Pfam annotation file")
    ap.add_argument("-o", "--output", required=True, 
                    help="Output TSV path")
    ap.add_argument("--one_row_per_qseqid", action="store_true",
                    help="Aggregate to one row per qseqid")
    
    args = ap.parse_args()
    
    print("Loading input files...", file=sys.stderr)
    
    # Load all inputs
    anno = read_tsv(args.anno_uniprot_besthit)
    t_uniprot = read_tsv(args.trans_uniprot)
    t_go = read_tsv(args.trans_go)
    t_kegg = read_tsv(args.trans_kegg)
    t_kog = read_tsv(args.trans_kog)
    t_pfam = read_tsv(args.trans_pfam)
    
    print(f"  Anno: {len(anno)} rows", file=sys.stderr)
    print(f"  UniProt: {len(t_uniprot)} rows", file=sys.stderr)
    print(f"  GO: {len(t_go)} rows", file=sys.stderr)
    print(f"  KEGG: {len(t_kegg)} rows", file=sys.stderr)
    print(f"  KOG: {len(t_kog)} rows", file=sys.stderr)
    print(f"  Pfam: {len(t_pfam)} rows", file=sys.stderr)
    
    # Build accession -> SeqID index
    print("Building index...", file=sys.stderr)
    acc2seqids = build_seqid_index(t_uniprot)
    
    # Aggregate GO, KEGG, KOG, Pfam by SeqID
    print("Aggregating annotations...", file=sys.stderr)
    
    # Check columns and aggregate
    go_cols = {}
    if "SeqID" in t_go.columns and "GOterm" in t_go.columns:
        go_cols = {"Accession": "semi", "GOterm": "semi", "NameSpace": "semi", "Description": "semi"}
        go_agg = aggregate_by_seqid(t_go[["SeqID"] + list(go_cols.keys())], go_cols)
    else:
        go_agg = pd.DataFrame(columns=["SeqID"])
    
    kegg_cols = {}
    if "SeqID" in t_kegg.columns and "Annotation" in t_kegg.columns:
        kegg_cols = {"Accession": "semi", "Annotation": "semi"}
        t_kegg_renamed = t_kegg[["SeqID", "Accession", "Annotation"]].rename(
            columns={"Accession": "kegg_accession", "Annotation": "kegg_annotation"})
        kegg_agg = aggregate_by_seqid(t_kegg_renamed, kegg_cols)
    else:
        kegg_agg = pd.DataFrame(columns=["SeqID"])
    
    kog_cols = {}
    if "SeqID" in t_kog.columns and "KogClassName" in t_kog.columns:
        kog_cols = {"KogClassName": "semi"}
        kog_agg = aggregate_by_seqid(t_kog[["SeqID"] + list(kog_cols.keys())], kog_cols)
    else:
        kog_agg = pd.DataFrame(columns=["SeqID"])
    
    pfam_cols = {}
    if "SeqID" in t_pfam.columns and "HMMProfile" in t_pfam.columns:
        pfam_cols = {"Accession": "semi", "HMMProfile": "semi", "Description": "semi"}
        t_pfam_renamed = t_pfam[["SeqID", "Accession", "HMMProfile", "Description"]].rename(
            columns={"Accession": "pfam_accession", "Description": "pfam_description"})
        pfam_agg = aggregate_by_seqid(t_pfam_renamed, pfam_cols)
    else:
        pfam_agg = pd.DataFrame(columns=["SeqID"])
    
    # Map accession to SeqID
    print("Mapping to SeqIDs...", file=sys.stderr)
    anno = anno.copy()
    anno["core_acc"] = anno["accession"].apply(normalize_core_uniprot)
    
    # Create base table
    rows = []
    for _, r in anno.iterrows():
        qseqid = r.get("qseqid", "")
        acc = r.get("accession", "")
        core = r.get("core_acc", "")
        seqids = acc2seqids.get(core, [])
        
        if len(seqids) == 0:
            rows.append({"qseqid": qseqid, "accession": acc, "SeqID": ""})
        else:
            if args.one_row_per_qseqid:
                rows.append({"qseqid": qseqid, "accession": acc, "SeqID": ";".join(sorted(set(seqids)))})
            else:
                for sid in seqids:
                    rows.append({"qseqid": qseqid, "accession": acc, "SeqID": sid})
    
    base = pd.DataFrame(rows)
    print(f"  Base table: {len(base)} rows", file=sys.stderr)
    
    # Merge annotations
    print("Merging annotations...", file=sys.stderr)
    out = base.merge(go_agg, on="SeqID", how="left")
    out = out.merge(kegg_agg, on="SeqID", how="left")
    out = out.merge(kog_agg, on="SeqID", how="left")
    out = out.merge(pfam_agg, on="SeqID", how="left")
    out = out.fillna("")
    
    # Select and order columns
    desired_cols = [
        "qseqid", "accession", "SeqID",
        "Accession", "GOterm", "NameSpace", "Description",
        "kegg_accession", "kegg_annotation",
        "KogClassName",
        "pfam_accession", "HMMProfile", "pfam_description"
    ]
    final_cols = [c for c in desired_cols if c in out.columns]
    out = out[final_cols]
    
    # Save
    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out.to_csv(out_path, sep="\t", index=False)
    
    print(f"[OK] Wrote {len(out)} rows to {out_path}", file=sys.stderr)

if __name__ == "__main__":
    main()
