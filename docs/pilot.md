# Pilot Evaluation Guide (ESP32-PICO, mTLS MQTT, HTTPS OTA)

This guide describes the end-to-end process to generate baseline evidence packages, change-impact reassessment packages,
manual triage packages, gold impact sets, and EQ3 metrics. The guide is written to support reproducibility and to avoid
implicit claims that exceed the measured results.

---

## 1) What we measure

### EQ1 — Baseline compilability and provenance completeness
- Requirement coverage by admissible evidence (using the requirement profile and Φ obligation matrix)
- Provenance completeness for evidence items (tool identity/version/params captured)

### EQ2 (optional) — Requirement→evidence linking workload and quality
- Precision/recall/F1 of proposed links (\Phi_b) vs gold links
- Time-to-completion (manual vs assisted)

### EQ3 (primary) — Incremental reassessment under change
For each change event Δi:
- Compare A2 refresh/re-test sets to adjudicated gold sets using precision/recall/Jaccard
- Compute reduction vs refresh-all (A0)
- Compare triage time A1 vs A2

---

## 2) Evidence model and file semantics

A baseline `Bt` is represented by:
- `evidence/baselines/Bt/manifest.json` (the baseline manifest)
- baseline-bound artefacts (firmware, configs, cert identifiers, SBOMs, reports, logs)
- test logs under `evidence/baselines/Bt/tests/`

The baseline manifest includes:
- `baseline_id`, `timestamp_utc`, `toe_ref`
- `evidence_items[]` (non-test artefacts) with `path` and `sha256`
- `tests[]` with `path`, `sha256`, and (optionally) outcome/provenance
- `observations[]` (optional operational summaries)

The scripts in `scripts/` are intentionally simple: they compute SHA-256 digests and build inventory lists.
You may enrich `artifact_type` and `provenance` fields later, but keep the file paths stable.

---

## 3) Infrastructure setup (mTLS MQTT + HTTPS OTA)

### 3.1 Generate pilot certificates (testing only)

```bash
chmod +x infra/*.sh
./infra/gen_certs.sh device-001
```

Outputs (generated, not committed):
- `infra/certs/ca.crt`, `ca.key`
- `infra/certs/broker.crt`, `broker.key`
- `infra/certs/ota_server.crt`, `ota_server.key`
- `infra/certs/device-001.crt`, `device-001.key`
- evidence-friendly identifiers:
  - `infra/certs/broker_cert_fingerprint.txt`
  - `infra/certs/device-001_cert_id.txt`

### 3.2 Start services

```bash
docker compose -f infra/docker-compose.yml up -d
```

Services:
- Mosquitto broker on `localhost:8883` with `require_certificate true` and topic ACLs
- Nginx OTA server on `https://localhost:8443/`

---

## 4) Baseline B0: collect real artefacts and tests

### 4.1 Firmware build (ESP-IDF)

This repo does not include your firmware source. Build in your own ESP-IDF workspace and copy outputs into:

- `evidence/baselines/B0/firmware/images/app.bin`
- `evidence/baselines/B0/firmware/images/bootloader.bin`
- `evidence/baselines/B0/firmware/config/sdkconfig`
- `evidence/baselines/B0/firmware/config/partition_table.csv` (if used)

### 4.2 OTA artefacts and signed manifest

Copy binaries into:
- `infra/ota/artifacts/release/bootloader.bin`
- `infra/ota/artifacts/release/app.bin`

Generate signed manifest:
```bash
./infra/make_ota_manifest.sh
```

Copy into evidence baseline:
- `evidence/baselines/B0/ota/release/manifest_signed.json`
- `evidence/baselines/B0/ota/release/ota_signing_pubkey.pem`

### 4.3 Minimal tests (evidence-bearing)

Run:
```bash
./infra/test_mqtt_mtls.sh device-001
./infra/test_broker_cert_validation.sh
```

Copy logs into:
- `evidence/baselines/B0/tests/mtls/mtls_handshake_authorised.log`
- `evidence/baselines/B0/tests/acl/topic_acl_allow_deny.log`
- `evidence/baselines/B0/tests/mtls/broker_cert_validation.log`

### 4.4 Generate baseline manifest for B0

```bash
python3 scripts/build_manifest.py evidence/baselines/B0 --baseline-id B0
```

This creates digests for all files under `evidence/baselines/B0/` (except the manifest itself).

---

## 5) Change events and baselines B1..Bn

A change event Δi is recorded under `evidence/changes/Di.json`.
Each change yields a new baseline directory `evidence/baselines/Bi/`.

Recommended workflow:
1) copy previous baseline `B(i-1)` → `Bi`
2) apply change Δi to infra/firmware
3) re-run only tests relevant to the change
4) replace affected artefacts in `evidence/baselines/Bi/...`
5) regenerate `evidence/baselines/Bi/manifest.json`

---

## 6) Worked example: D3 broker certificate rotation (B0 → B1)

### 6.1 Create B1
```bash
cp -a evidence/baselines/B0 evidence/baselines/B1
```

### 6.2 Rotate broker certificate and restart broker
```bash
./infra/rotate_broker_cert.sh
docker compose -f infra/docker-compose.yml restart mosquitto
```

### 6.3 Re-run tests
```bash
./infra/test_mqtt_mtls.sh device-001
./infra/test_broker_cert_validation.sh
```

### 6.4 Copy updated artefacts/logs into B1
At minimum, update:
- `mqtt/broker/tls/broker_cert.pem` (new certificate)
- `mqtt/broker/tls/ca_bundle.pem` (same CA, but copy for traceability)
- `mqtt/device/tls/trust_store_snapshot.pem` (device trust store snapshot)
- test logs under `tests/`

### 6.5 Generate B1 manifest
```bash
python3 scripts/build_manifest.py evidence/baselines/B1 --baseline-id B1
```

---

## 7) Reassessment packages (A2 and A1) for EQ3

### 7.1 A2 targeted reassessment package (graph-based or rule-based proxy)
Create:
`evidence/baselines/B1/traceability/impact/impact_A2_D3_broker_cert_rotation.json`

Fields:
- `change_id`, `baseline_from`, `baseline_to`
- `impacted_requirements` (e.g., R14–R16 for comms, R20 for config governance)
- `impact_package.refresh_paths[]`
- `impact_package.retest_paths[]`
- `generated_by.tool`, `tool_version`, `params`

### 7.2 A1 manual triage package (+ time)
Create:
`evidence/triage/A1_manual/D3_broker_cert_rotation.json`

Fields:
- `triage_time_minutes`
- `refresh_paths[]`, `retest_paths[]`
- short rationale

---

## 8) Gold impact sets (two annotators + adjudication)

For each change event:
- Annotator A produces `evidence/gold/impact/Di_A.json`
- Annotator B produces `evidence/gold/impact/Di_B.json`
- Adjudication produces `evidence/gold/impact/Di_adjudicated.json`

Gold sets use baseline-relative `*_paths` rather than evidence IDs to avoid renumbering artifacts across baselines.

---

## 9) Compute EQ3 metrics

Run:
```bash
python3 scripts/compute_eq3_for_change.py \
  --change-id D3_broker_cert_rotation \
  --baseline-from-manifest evidence/baselines/B0/manifest.json \
  --a2-impact evidence/baselines/B1/traceability/impact/impact_A2_D3_broker_cert_rotation.json \
  --a1-manual evidence/triage/A1_manual/D3_broker_cert_rotation.json \
  --gold-adjudicated evidence/gold/impact/D3_broker_cert_rotation_adjudicated.json \
  --a2-time-minutes 0.40
```

The script prints a `CSV_ROW_EQ3` line that can be copied into the paper’s EQ3 table.

---

## 10) What to commit

Commit:
- baseline templates and manifests (once they are based on real artefacts)
- change definitions, triage and gold sets
- scripts, docs, and infra configs

Do not commit:
- private keys
- generated logs under `infra/logs/`
- large OTA binaries under `infra/ota/artifacts/release/`

### Evidence export helper

To reduce manual copy errors, you can use `infra/export_evidence.sh` to copy infra artefacts and logs into a baseline directory:

```bash
./infra/export_evidence.sh B0 device-001
python3 scripts/build_manifest.py evidence/baselines/B0 --baseline-id B0
```

Set `FIRMWARE_BUILD_DIR` to your ESP-IDF build directory to copy firmware artefacts automatically:

```bash
export FIRMWARE_BUILD_DIR=/path/to/your/firmware/build
./infra/export_evidence.sh B0 device-001
```


## Evidence export helper

To minimise manual copy errors, use:

```bash
./infra/export_evidence.sh <BASELINE_ID> <DEVICE_ID> [FIRMWARE_BUILD_DIR]
```

Examples:

```bash
./infra/export_evidence.sh B0 device-001
./infra/export_evidence.sh B0 device-001 /path/to/firmware/build
```

After exporting, generate the baseline manifest:

```bash
python3 scripts/build_manifest.py evidence/baselines/B0 --baseline-id B0
```
