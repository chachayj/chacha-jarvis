#!/bin/sh
set -e

CERT_DIR="/opt/emqx/etc/certs"

echo "🔧 Checking EMQX certificates..."
if [ ! -f "$CERT_DIR/cert.pem" ] || [ ! -f "$CERT_DIR/key.pem" ] || [ ! -f "$CERT_DIR/cacert.pem" ]; then
  echo "⚙️  Generating new self-signed certs..."
  mkdir -p "$CERT_DIR"

  # Root CA
  openssl req -x509 -newkey rsa:2048 -keyout "$CERT_DIR/ca.key" -out "$CERT_DIR/cacert.pem" \
    -days 365 -nodes -subj "/CN=emqx.local"

  # Server key & CSR
  openssl req -newkey rsa:2048 -keyout "$CERT_DIR/key.pem" -out "$CERT_DIR/server.csr" \
    -nodes -subj "/CN=emqx.local"

  # Server cert
  openssl x509 -req -in "$CERT_DIR/server.csr" -CA "$CERT_DIR/cacert.pem" -CAkey "$CERT_DIR/ca.key" \
    -CAcreateserial -out "$CERT_DIR/cert.pem" -days 365

  echo "✅ Certificates generated."
else
  echo "✅ Certificates already exist, skipping generation."
fi

echo "🔧 Fixing EMQX directory permissions..."
chown -R 1000:1000 /opt/emqx/data /opt/emqx/log "$CERT_DIR"
chmod -R 755 /opt/emqx/data /opt/emqx/log "$CERT_DIR"

echo "🚀 Starting EMQX..."
/usr/bin/docker-entrypoint.sh emqx foreground
