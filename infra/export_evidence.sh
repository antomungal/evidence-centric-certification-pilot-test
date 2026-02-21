#!/usr/bin/env bash
set -euo pipefail

# export_evidence.sh
# Copies infra artefacts and logs into a baseline directory under evidence/baselines/Bt/.
#
# Usage:
#   ./infra/export_evidence.sh <BASELINE_ID> <DEVICE_ID> [FIRMWARE_BUILD_DIR]
#
# Examples:
#   ./infra/export_evidence.sh B0 device-001
#   ./infra/export_evidence.sh B0 device-001 /path/to/firmware/build
#
# Notes:
# - This script does NOT copy any private keys into evidence/.
# - If a firmware build directory is provided (or FIRMWARE_BUILD_DIR is set), the script
#   will attempt to copy app.bin/bootloader.bin and common config artefacts.

BASELINE_ID="${1:-}"
DEVICE_ID="${2:-device-001}"
FW_BUILD_DIR_ARG="${3:-}"

if [ -z "$BASELINE_ID" ]; then
  echo "ERROR: baseline id required (e.g., B0)."
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EVD_BASE="$REPO_ROOT/evidence/baselines/${BASELINE_ID}"
INFRA="$REPO_ROOT/infra"

if [ ! -d "$EVD_BASE" ]; then
  echo "ERROR: baseline directory does not exist: $EVD_BASE"
  echo "Create it first (e.g., cp -a evidence/baselines/B0 evidence/baselines/B1)."
  exit 1
fi

mkdir -p "$EVD_BASE/mqtt/broker/config" "$EVD_BASE/mqtt/broker/tls" "$EVD_BASE/mqtt/broker/container"
mkdir -p "$EVD_BASE/mqtt/device/tls" "$EVD_BASE/mqtt/device/credentials"
mkdir -p "$EVD_BASE/ota/release" "$EVD_BASE/ota/server/config" "$EVD_BASE/ota/server/container"
mkdir -p "$EVD_BASE/tests/mtls" "$EVD_BASE/tests/acl" "$EVD_BASE/tests/ota"
mkdir -p "$EVD_BASE/ops/observations"
mkdir -p "$EVD_BASE/firmware/images" "$EVD_BASE/firmware/config"

echo "[1/7] Export infra configs (broker + ACL + OTA server config)"
cp "$INFRA/mosquitto/mosquitto.conf" "$EVD_BASE/mqtt/broker/config/mosquitto.conf"
cp "$INFRA/mosquitto/aclfile" "$EVD_BASE/mqtt/broker/config/aclfile"
cp "$INFRA/ota/nginx.conf" "$EVD_BASE/ota/server/config/nginx.conf" 2>/dev/null || true
cp "$INFRA/docker-compose.yml" "$EVD_BASE/ota/server/config/docker-compose.yml" 2>/dev/null || true

echo "[2/7] Export public trust material (no private keys)"
cp "$INFRA/certs/ca.crt" "$EVD_BASE/mqtt/broker/tls/ca_bundle.pem"
cp "$INFRA/certs/broker.crt" "$EVD_BASE/mqtt/broker/tls/broker_cert.pem"
cp "$INFRA/certs/broker_cert_fingerprint.txt" "$EVD_BASE/mqtt/broker/tls/broker_key_fingerprint.txt" 2>/dev/null || true
cp "$INFRA/certs/ca.crt" "$EVD_BASE/mqtt/device/tls/trust_store_snapshot.pem"
cp "$INFRA/certs/${DEVICE_ID}_cert_id.txt" "$EVD_BASE/mqtt/device/credentials/device_cert_id.txt" 2>/dev/null || true

echo "[3/7] Export OTA manifest + public verification key (if present)"
if [ -f "$INFRA/certs/ota_signing.pub" ]; then
  cp "$INFRA/certs/ota_signing.pub" "$EVD_BASE/ota/release/ota_signing_pubkey.pem"
fi
if [ -f "$INFRA/ota/artifacts/manifest_signed.json" ]; then
  cp "$INFRA/ota/artifacts/manifest_signed.json" "$EVD_BASE/ota/release/manifest_signed.json"
fi

echo "[4/7] Export container image digests (if present)"
if [ -f "$INFRA/mosquitto_image_digest.txt" ]; then
  cp "$INFRA/mosquitto_image_digest.txt" "$EVD_BASE/mqtt/broker/container/image_digest.txt"
fi
if [ -f "$INFRA/ota_image_digest.txt" ]; then
  cp "$INFRA/ota_image_digest.txt" "$EVD_BASE/ota/server/container/image_digest.txt"
fi

echo "[5/7] Export test logs (if present)"
if [ -f "$INFRA/logs/mqtt_pub_${DEVICE_ID}.log" ]; then
  cp "$INFRA/logs/mqtt_pub_${DEVICE_ID}.log" "$EVD_BASE/tests/mtls/mtls_handshake_authorised.log"
fi
if [ -f "$INFRA/logs/mqtt_pub_forbidden_${DEVICE_ID}.log" ]; then
  cp "$INFRA/logs/mqtt_pub_forbidden_${DEVICE_ID}.log" "$EVD_BASE/tests/acl/topic_acl_allow_deny.log"
fi
if [ -f "$INFRA/logs/broker_cert_validation.log" ]; then
  cp "$INFRA/logs/broker_cert_validation.log" "$EVD_BASE/tests/mtls/broker_cert_validation.log"
fi

echo "[6/7] Optional: export broker runtime logs as observations"
if [ -f "$INFRA/logs/mosquitto/mosquitto.log" ]; then
  cp "$INFRA/logs/mosquitto/mosquitto.log" "$EVD_BASE/ops/observations/broker_runtime.log"
fi

echo "[7/7] Firmware artefacts (optional automated copy)"
FW_BUILD_DIR="${FW_BUILD_DIR_ARG:-${FIRMWARE_BUILD_DIR:-}}"
if [ -n "$FW_BUILD_DIR" ]; then
  if [ ! -d "$FW_BUILD_DIR" ]; then
    echo "  WARNING: firmware build dir does not exist: $FW_BUILD_DIR"
  else
    # bootloader
    if [ -f "$FW_BUILD_DIR/bootloader/bootloader.bin" ]; then
      cp "$FW_BUILD_DIR/bootloader/bootloader.bin" "$EVD_BASE/firmware/images/bootloader.bin"
    fi
    # app (pick the largest .bin at top-level as a heuristic)
    APP_BIN="$(ls -1S "$FW_BUILD_DIR"/*.bin 2>/dev/null | head -n 1 || true)"
    if [ -n "$APP_BIN" ]; then
      cp "$APP_BIN" "$EVD_BASE/firmware/images/app.bin"
    fi
    # sdkconfig is typically one level above build/
    FW_PROJECT_DIR="$(cd "$FW_BUILD_DIR/.." && pwd)"
    if [ -f "$FW_PROJECT_DIR/sdkconfig" ]; then
      cp "$FW_PROJECT_DIR/sdkconfig" "$EVD_BASE/firmware/config/sdkconfig"
    fi
    # partition table (common names)
    if [ -f "$FW_PROJECT_DIR/partitions.csv" ]; then
      cp "$FW_PROJECT_DIR/partitions.csv" "$EVD_BASE/firmware/config/partition_table.csv"
    elif [ -f "$FW_BUILD_DIR/partition_table/partition-table.bin" ]; then
      # Not a CSV, but still useful as evidence in some setups
      cp "$FW_BUILD_DIR/partition_table/partition-table.bin" "$EVD_BASE/firmware/config/partition_table.bin"
    fi
  fi
else
  echo "  (skipped) Provide a firmware build directory as argument #3 or set FIRMWARE_BUILD_DIR."
fi

echo "Export completed to: $EVD_BASE"
echo "Next: python3 scripts/build_manifest.py evidence/baselines/${BASELINE_ID} --baseline-id ${BASELINE_ID}"
