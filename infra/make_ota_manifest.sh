#!/usr/bin/env bash
set -euo pipefail

REL_DIR="infra/ota/artifacts/release"
mkdir -p "$REL_DIR"
MANIFEST="infra/ota/artifacts/manifest_signed.json"

BOOT="$REL_DIR/bootloader.bin"
APP="$REL_DIR/app.bin"

if [ ! -f "$BOOT" ] || [ ! -f "$APP" ]; then
  echo "ERROR: Put bootloader.bin and app.bin into $REL_DIR first."
  exit 1
fi

BOOT_SHA="$(sha256sum "$BOOT" | awk '{print $1}')"
APP_SHA="$(sha256sum "$APP" | awk '{print $1}')"

# Separate OTA signing key from the CA (pilot-only setup).
SIGN_KEY="infra/certs/ota_signing.key"
SIGN_PUB="infra/certs/ota_signing.pub"

if [ ! -f "$SIGN_KEY" ]; then
  openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "$SIGN_KEY"
  openssl rsa -in "$SIGN_KEY" -pubout -out "$SIGN_PUB"
fi

TMP="infra/ota/artifacts/manifest_payload.json"
cat > "$TMP" <<EOF
{
  "version": "0.1.0",
  "artifacts": [
    {"name": "bootloader.bin", "sha256": "${BOOT_SHA}"},
    {"name": "app.bin", "sha256": "${APP_SHA}"}
  ]
}
EOF

SIG_BIN="infra/ota/artifacts/manifest_signature.bin"
openssl dgst -sha256 -sign "$SIGN_KEY" -out "$SIG_BIN" "$TMP"
SIG_B64="$(base64 -w0 "$SIG_BIN")"

cat > "$MANIFEST" <<EOF
{
  "version": "0.1.0",
  "artifacts": [
    {"name": "bootloader.bin", "sha256": "${BOOT_SHA}"},
    {"name": "app.bin", "sha256": "${APP_SHA}"}
  ],
  "signature_b64": "${SIG_B64}"
}
EOF

echo "Wrote $MANIFEST"
