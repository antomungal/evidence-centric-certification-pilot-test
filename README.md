# evidence-centric-certification-pilot

**Evidence baselines + traceability graph pilot for incremental security reassessment under change (ESP32-PICO, mTLS MQTT, HTTPS OTA).**

This repository provides a reproducible workflow to generate the artefacts required to populate the paper’s *Pilot Results*
subsection (EQ1–EQ3):

- **Baselines** `B0..Bn`: versioned evidence packages bound to an IoT ToE (ESP32-PICO + broker + OTA server)
- **Change events** `Δi`: controlled changes that transform `B(i-1)` into `Bi`
- **Reassessment packages**:
  - **A0 refresh-all** (implicit): refresh all evidence after each change
  - **A1 manual triage**: human-defined minimal refresh/re-test sets (+ time)
  - **A2 targeted reassessment**: graph-based (or rule-based proxy) refresh/re-test sets
- **Gold impact sets**: two annotators + adjudication, used as reference for EQ3 metrics
- **Scripts**:
  - generate baseline manifests (`manifest.json`) with SHA-256 digests
  - compute EQ3 metrics (precision/recall/Jaccard + reduction + time) and output table-ready CSV rows

The pilot does **not** claim a product certification outcome. It evaluates operational claims of an evidence-centric certification loop:
baseline compilability, traceability workload, and incremental reassessment under change.

## Repository entry points

- **Full end-to-end guide:** `docs/pilot.md`
- **Infrastructure:** `infra/` (Docker Compose for mTLS MQTT + HTTPS OTA)
- **Evidence store:** `evidence/` (baselines, changes, triage, gold sets)
- **Evaluation scripts:** `scripts/`

## Quickstart (local)

> You will need Docker, OpenSSL, Python 3.10+, and a working ESP-IDF toolchain.

1) Generate pilot certificates (testing only; do not commit private keys):
```bash
chmod +x infra/*.sh
./infra/gen_certs.sh device-001
```

2) Start infra:
```bash
docker compose -f infra/docker-compose.yml up -d
```

3) Build firmware in your own ESP-IDF project (not included in this repo). Copy outputs into baseline `B0`:
- `app.bin`, `bootloader.bin`, `sdkconfig`, `partition_table.csv` (if applicable)

4) Create OTA manifest (requires `bootloader.bin` and `app.bin` in `infra/ota/artifacts/release/`):
```bash
./infra/make_ota_manifest.sh
```

5) Run minimal tests (broker mTLS + ACL, broker cert validation):
```bash
./infra/test_mqtt_mtls.sh device-001
./infra/test_broker_cert_validation.sh
```

6) Copy evidence into `evidence/baselines/B0/...` and generate baseline manifest:
```bash
python3 scripts/build_manifest.py evidence/baselines/B0 --baseline-id B0
```

7) Execute the worked change event **D3 broker certificate rotation** (B0 → B1), then compute EQ3 metrics:
```bash
./infra/rotate_broker_cert.sh
docker compose -f infra/docker-compose.yml restart mosquitto
./infra/test_mqtt_mtls.sh device-001
./infra/test_broker_cert_validation.sh

# copy updated artefacts/logs into evidence/baselines/B1/... and run:
python3 scripts/build_manifest.py evidence/baselines/B1 --baseline-id B1

# compute EQ3 (paths below assume you created the A2/A1/gold files described in docs/pilot.md)
python3 scripts/compute_eq3_for_change.py \
  --change-id D3_broker_cert_rotation \
  --baseline-from-manifest evidence/baselines/B0/manifest.json \
  --a2-impact evidence/baselines/B1/traceability/impact/impact_A2_D3_broker_cert_rotation.json \
  --a1-manual evidence/triage/A1_manual/D3_broker_cert_rotation.json \
  --gold-adjudicated evidence/gold/impact/D3_broker_cert_rotation_adjudicated.json \
  --a2-time-minutes 0.40
```

## Security notes

- Never commit private keys (`infra/certs/*.key`) or signing private keys.
- The evidence repository stores only public identifiers (fingerprints, public keys, certificate IDs) and configuration/procedure records.

## Citation

If you use this pilot structure in academic work, cite the accompanying paper (to be added).

> Tip: use `./infra/export_evidence.sh B0 device-001` to copy infra artefacts/logs into `evidence/baselines/B0/` before generating the manifest.


### Evidence export helper

Use the helper to copy infra artefacts/logs into a baseline directory:

```bash
./infra/export_evidence.sh B0 device-001
```

To also copy firmware outputs automatically, pass the ESP-IDF build directory (or set `FIRMWARE_BUILD_DIR`):

```bash
./infra/export_evidence.sh B0 device-001 /path/to/firmware/build
# or
export FIRMWARE_BUILD_DIR=/path/to/firmware/build
./infra/export_evidence.sh B0 device-001
```
