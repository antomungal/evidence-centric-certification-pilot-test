#!/usr/bin/env bash
set -euo pipefail

CERT_DIR="$(cd "$(dirname "$0")" && pwd)/certs"
LOG_DIR="$(cd "$(dirname "$0")" && pwd)/logs"
mkdir -p "$LOG_DIR"

CA="$CERT_DIR/ca.crt"
EXP_FP_FILE="$CERT_DIR/broker_cert_fingerprint.txt"
OUT="$LOG_DIR/broker_cert_validation.log"

{
  echo "=== observed broker cert fingerprint ==="
  openssl s_client -connect localhost:8883 -showcerts -CAfile "$CA" </dev/null 2>/dev/null \
    | openssl x509 -noout -fingerprint -sha256
  echo
  echo "=== expected broker cert fingerprint ==="
  cat "$EXP_FP_FILE"
} | tee "$OUT"
