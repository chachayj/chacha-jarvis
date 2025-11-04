#!/bin/sh
# wait-for-it.sh <host>:<port> [--timeout=SECONDS] [--strict] [--] <command> [args]
hostport=$1
shift
timeout=${2:-30}
while ! nc -z ${hostport%:*} ${hostport#*:}; do
  echo "⏳ Waiting for $hostport..."
  sleep 2
  timeout=$((timeout - 2))
  [ $timeout -le 0 ] && echo "❌ Timeout waiting for $hostport" && exit 1
done
echo "✅ $hostport is up, starting app..."
exec "$@"
