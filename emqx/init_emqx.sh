#!/bin/sh
set -e

CERT_DIR="/opt/emqx/etc/certs"
EXT_FILE="/tmp/emqx_ext.cnf"

echo "🔧 Checking EMQX certificates..."
if [ ! -f "$CERT_DIR/cert.pem" ] || [ ! -f "$CERT_DIR/key.pem" ] || [ ! -f "$CERT_DIR/cacert.pem" ]; then
  echo "⚙️  Generating new self-signed certs..."
  mkdir -p "$CERT_DIR"

  # SAN 확장 설정 파일 생성
  echo "subjectAltName=DNS:emqx,DNS:localhost" > "$EXT_FILE"

  # Root CA 생성
  openssl req -x509 -newkey rsa:2048 \
    -keyout "$CERT_DIR/ca.key" \
    -out "$CERT_DIR/cacert.pem" \
    -days 365 -nodes -subj "/CN=emqx"

  # Server 키 & CSR 생성
  openssl req -newkey rsa:2048 \
    -keyout "$CERT_DIR/key.pem" \
    -out "$CERT_DIR/server.csr" \
    -nodes -subj "/CN=emqx"

  # Server cert 생성 (SAN 포함)
  openssl x509 -req \
    -in "$CERT_DIR/server.csr" \
    -CA "$CERT_DIR/cacert.pem" \
    -CAkey "$CERT_DIR/ca.key" \
    -CAcreateserial \
    -out "$CERT_DIR/cert.pem" \
    -days 365 \
    -extfile "$EXT_FILE"

  rm -f "$EXT_FILE"
  echo "✅ Certificates generated with SAN (DNS:emqx, DNS:localhost)."
else
  echo "✅ Certificates already exist, skipping generation."
fi

echo "🔧 Fixing EMQX directory permissions..."
chown -R 1000:1000 /opt/emqx/data /opt/emqx/log "$CERT_DIR"
chmod -R 755 /opt/emqx/data /opt/emqx/log "$CERT_DIR"

echo "🚀 Starting EMQX..."
/usr/bin/docker-entrypoint.sh emqx foreground
