#!/usr/bin/env python3
import json
from pathlib import Path

def jaccard(a, b):
    a, b = set(a), set(b)
    return len(a & b) / len(a | b) if (a | b) else 1.0

def main():
    base = Path("evidence/gold/impact")
    A = json.loads((base/"D3_broker_cert_rotation_A.json").read_text(encoding="utf-8"))
    B = json.loads((base/"D3_broker_cert_rotation_B.json").read_text(encoding="utf-8"))
    print("Jaccard(refresh_paths):", jaccard(A["refresh_paths"], B["refresh_paths"]))
    print("Jaccard(retest_paths):", jaccard(A["retest_paths"], B["retest_paths"]))

if __name__ == "__main__":
    main()
