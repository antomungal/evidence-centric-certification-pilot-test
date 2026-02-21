## Gold impact annotation protocol (pilot EQ3)

Inputs per change:
- change description (evidence/changes/D*.json)
- baseline manifests (evidence/baselines/B*/manifest.json)
- requirement profile and Φ obligation matrix (evidence/baselines/B*/traceability/*.csv)

Task:
Annotators independently define:
1) minimal evidence refresh set (paths) required to reassess affected requirements under the stated scope and threat model
2) minimal re-test set (paths) required to revalidate affected controls

Rules:
- Prefer minimality: include an item only if omitting it would prevent a justified reassessment.
- Use baseline-relative paths for refresh/re-test items.
- Do not include private key material.
- Provide a short rationale (1–3 sentences).
