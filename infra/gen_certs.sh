#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="$(cd "$(dirname "$0")" && pwd)/certs"
mkdir -p "$OUT_DIR"

DAYS=365

# Root CA
openssl req -x509 -newkey rsa:4096 -sha256 -days $DAYS -nodes \
  -subj "/CN=Pilot-Root-CA" \
  -keyout "$OUT_DIR/ca.key" -out "$OUT_DIR/ca.crt"

# Broker cert
openssl req -newkey rsa:2048 -nodes -subj "/CN=broker" \
  -keyout "$OUT_DIR/broker.key" -out "$OUT_DIR/broker.csr"
openssl x509 -req -in "$OUT_DIR/broker.csr" -CA "$OUT_DIR/ca.crt" -CAkey "$OUT_DIR/ca.key" -CAcreateserial \
  -days $DAYS -sha256 -out "$OUT_DIR/broker.crt"

# OTA server cert
openssl req -newkey rsa:2048 -nodes -subj "/CN=ota-server" \
  -keyout "$OUT_DIR/ota_server.key" -out "$OUT_DIR/ota_server.csr"
openssl x509 -req -in "$OUT_DIR/ota_server.csr" -CA "$OUT_DIR/ca.crt" -CAkey "$OUT_DIR/ca.key" -CAcreateserial \
  -days $DAYS -sha256 -out "$OUT_DIR/ota_server.crt"

# Device client cert
DEVICE_ID="${1:-device-001}"
openssl req -newkey rsa:2048 -nodes -subj "/CN=${DEVICE_ID}" \
  -keyout "$OUT_DIR/${DEVICE_ID}.key" -out "$OUT_DIR/${DEVICE_ID}.csr"
openssl x509 -req -in "$OUT_DIR/${DEVICE_ID}.csr" -CA "$OUT_DIR/ca.crt" -CAkey "$OUT_DIR/ca.key" -CAcreateserial \
  -days $DAYS -sha256 -out "$OUT_DIR/${DEVICE_ID}.crt"

# Evidence-friendly identifiers
openssl x509 -in "$OUT_DIR/broker.crt" -noout -fingerprint -sha256 > "$OUT_DIR/broker_cert_fingerprint.txt"
openssl x509 -in "$OUT_DIR/${DEVICE_ID}.crt" -noout -serial -subject > "$OUT_DIR/${DEVICE_ID}_cert_id.txt"

echo "Generated certs in $OUT_DIR for DEVICE_ID=$DEVICE_ID"
