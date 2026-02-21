#!/usr/bin/env bash
set -euo pipefail

CERT_DIR="$(cd "$(dirname "$0")" && pwd)/certs"
CA_CRT="$CERT_DIR/ca.crt"
CA_KEY="$CERT_DIR/ca.key"

openssl req -newkey rsa:2048 -nodes -subj "/CN=broker" \
  -keyout "$CERT_DIR/broker.key" -out "$CERT_DIR/broker.csr"

openssl x509 -req -in "$CERT_DIR/broker.csr" \
  -CA "$CA_CRT" -CAkey "$CA_KEY" -CAcreateserial \
  -days 365 -sha256 -out "$CERT_DIR/broker.crt"

openssl x509 -in "$CERT_DIR/broker.crt" -noout -fingerprint -sha256 > "$CERT_DIR/broker_cert_fingerprint.txt"
echo "Rotated broker certificate."
