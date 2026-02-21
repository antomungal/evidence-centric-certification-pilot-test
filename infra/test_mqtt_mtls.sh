#!/usr/bin/env bash
set -euo pipefail
DEVICE_ID="${1:-device-001}"

CA="infra/certs/ca.crt"
CERT="infra/certs/${DEVICE_ID}.crt"
KEY="infra/certs/${DEVICE_ID}.key"

mkdir -p infra/logs

# Allowed publish to per-device namespace
docker run --rm --network host eclipse-mosquitto:2 \
  mosquitto_pub -h localhost -p 8883 --cafile "$CA" --cert "$CERT" --key "$KEY" \
  -t "devices/${DEVICE_ID}/telemetry" -m "hello" -d 2>&1 | tee "infra/logs/mqtt_pub_${DEVICE_ID}.log"

# Forbidden publish (expected deny)
docker run --rm --network host eclipse-mosquitto:2 \
  mosquitto_pub -h localhost -p 8883 --cafile "$CA" --cert "$CERT" --key "$KEY" \
  -t "devices/other/telemetry" -m "nope" -d 2>&1 | tee "infra/logs/mqtt_pub_forbidden_${DEVICE_ID}.log" || true
