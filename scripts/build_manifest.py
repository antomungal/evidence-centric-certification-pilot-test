#!/usr/bin/env python3
import json, hashlib
from pathlib import Path
from datetime import datetime, timezone

def sha256_file(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(1024*1024), b""):
            h.update(chunk)
    return h.hexdigest()

def main():
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("baseline_dir", help="Path to evidence/baselines/Bt")
    ap.add_argument("--baseline-id", required=True)
    args = ap.parse_args()

    base = Path(args.baseline_dir)
    mf_path = base / "manifest.json"
    mf = json.loads(mf_path.read_text(encoding="utf-8"))

    mf["baseline_id"] = args.baseline_id
    mf["timestamp_utc"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    evidence_items, tests, observations = [], [], []
    for p in base.rglob("*"):
        if not p.is_file() or p.name == "manifest.json":
            continue
        rel = str(p.relative_to(base))
        digest = sha256_file(p)

        if rel.startswith("tests/"):
            tests.append({
                "test_id": f"T-{args.baseline_id}-{p.stem}",
                "path": rel,
                "sha256": digest,
                "outcome": "TBD",
                "provenance": {"tool": "TBD", "tool_version": "TBD", "params": {}}
            })
        elif rel.startswith("ops/observations/"):
            observations.append({
                "observation_id": f"O-{args.baseline_id}-{p.stem}",
                "path": rel,
                "sha256": digest,
                "provenance": {"producer": "TBD"}
            })
        else:
            evidence_items.append({
                "evidence_id": f"E-{args.baseline_id}-{len(evidence_items)+1:03d}",
                "artifact_type": "TBD",
                "path": rel,
                "sha256": digest,
                "provenance": {"producer": "TBD", "tool": "TBD", "tool_version": "TBD", "params": {}, "inputs": {}}
            })

    mf["evidence_items"] = evidence_items
    mf["tests"] = tests
    mf["observations"] = observations

    mf_path.write_text(json.dumps(mf, indent=2), encoding="utf-8")
    print(f"Wrote {mf_path} with {len(evidence_items)} evidence items, {len(tests)} tests, {len(observations)} observations.")

if __name__ == "__main__":
    main()
