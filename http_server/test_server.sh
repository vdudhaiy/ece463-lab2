#!/usr/bin/env bash

# Usage: ./test_http_server.sh [SERVPORT] [DBPORT]
# Example: ./test_http_server.sh 8080 5432

SERVPORT=${1:-36171}
DBPORT=${2:-56171}

SERVER_CMD="./http_server $SERVPORT $DBPORT"

# Wait a moment to avoid bind: already in use from previous runs
echo "Waiting to ensure bind:already in use does not occur (not foolproof)..."
sleep 10

# Start server in background
$SERVER_CMD &
SERVER_PID=$!
sleep 1 # give server time to start

cleanup() {
  echo "Stopping server..."
  # kill $(lsof -i :$SERVPORT | awk 'NR>1 {print $2}')
  kill $SERVER_PID 2>/dev/null || true
  wait $SERVER_PID 2>/dev/null || true
}
trap cleanup EXIT

echo "=== Running HTTP Server Tests on port $SERVPORT ==="

### TESTS ###
# 1. HTTP/1.0 GET (force with nc)
echo "[TEST] HTTP/1.0 GET /index.html"

# 2. HTTP/1.1 GET (wget handles Host header automatically)
echo "[TEST] HTTP/1.1 GET /index.html"

# # 3. HTTP/1.0 POST (nc needed to force POST)
echo "[TEST] HTTP/1.0 POST /index.html"


# # 4. Bad request URL (must use nc, wget always fixes path)
echo "[TEST] HTTP/1.0 GET badurl"


# # 5. Disallow '/../' 
echo "[TEST] HTTP/1.0 GET /../secret.txt"


# # 6. Disallow ending with /.. 
echo "[TEST] HTTP/1.0 GET /dir/.."


# # 7. Directory with trailing slash
echo "[TEST] HTTP/1.0 GET /docs/"


# # 8. Directory without trailing slash
echo "[TEST] HTTP/1.0 GET /docs"


# # 9. Nonexistent file should return 404
echo "[TEST] HTTP/1.0 GET /doesnotexist.html"


echo "=== Tests complete ==="
sleep 5 # give server time to finish logging before cleanup
