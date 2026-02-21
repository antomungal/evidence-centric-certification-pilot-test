#!/usr/bin/env python3
import argparse
import json
from pathlib import Path
from typing import Dict, Set, Tuple

def load_json(p: Path) -> Dict:
    return json.loads(p.read_text(encoding="utf-8"))

def jaccard(a: Set[str], b: Set[str]) -> float:
    if not a and not b:
        return 1.0
    return len(a & b) / len(a | b)

def precision_recall(pred: Set[str], gold: Set[str]) -> Tuple[float, float]:
    if not pred and not gold:
        return 1.0, 1.0
    if not pred and gold:
        return 0.0, 0.0
    tp = len(pred & gold)
    prec = tp / len(pred) if pred else 0.0
    rec = tp / len(gold) if gold else 1.0
    return prec, rec

def main():
    ap = argparse.ArgumentParser(description="Compute EQ3 metrics for a single change event.")
    ap.add_argument("--change-id", required=True)
    ap.add_argument("--baseline-from-manifest", required=True, type=Path)
    ap.add_argument("--a2-impact", required=True, type=Path)
    ap.add_argument("--a1-manual", required=True, type=Path)
    ap.add_argument("--gold-adjudicated", required=True, type=Path)
    ap.add_argument("--a2-time-minutes", default=None, type=float)
    args = ap.parse_args()

    b0 = load_json(args.baseline_from_manifest)
    a2 = load_json(args.a2_impact)
    a1 = load_json(args.a1_manual)
    gold = load_json(args.gold_adjudicated)

    gold_refresh = set(gold.get("refresh_paths", []))
    gold_retest = set(gold.get("retest_paths", []))
    pkg = a2.get("impact_package", {})
    a2_refresh = set(pkg.get("refresh_paths", []))
    a2_retest = set(pkg.get("retest_paths", []))

    prec_e, rec_e = precision_recall(a2_refresh, gold_refresh)
    jac_e = jaccard(a2_refresh, gold_refresh)

    e_a0 = len(b0.get("evidence_items", []))
    reduct = 1.0 - (len(a2_refresh) / e_a0 if e_a0 > 0 else 0.0)

    t_a1 = float(a1.get("triage_time_minutes", 0.0))
    t_a2 = args.a2_time_minutes

    triage_cell = f"{t_a1:.2f}/" + ("NA" if t_a2 is None else f"{t_a2:.2f}")

    # CSV columns: Change, |E*|, |E_A2|, Prec, Rec, Jaccard, Reduct vs A0, Triage time (A1/A2)
    csv_row = ",".join([
        args.change_id,
        str(len(gold_refresh)),
        str(len(a2_refresh)),
        f"{prec_e:.3f}",
        f"{rec_e:.3f}",
        f"{jac_e:.3f}",
        f"{reduct:.3f}",
        triage_cell
    ])

    print("CSV_ROW_EQ3:")
    print(csv_row)

if __name__ == "__main__":
    main()
