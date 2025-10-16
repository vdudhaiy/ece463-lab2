#!/usr/bin/env bash

SERVPORT=${1:-36171}
DBPORT=${2:-56171}

SERVER_CMD="./http_server $SERVPORT $DBPORT"
DB_CMD="./db_server $DBPORT"

# Wait a moment to avoid bind: already in use from previous runs
echo "Waiting to ensure bind:already in use does not occur (not foolproof)..."
echo "If you end up failing most test cases really quickly, try waiting longer."
sleep 10

# Start server in background
($SERVER_CMD > http_server.log 2>&1) &
SERVER_PID=$!
sleep 1 # give server time to start

cleanup() {
    # For some reason, it doesn't always kill server on exit. Hence the longer wait above.
  echo "Stopping HTTP server..."
  # kill $(lsof -i :$SERVPORT | awk 'NR>1 {print $2}')
  kill $SERVER_PID 2>/dev/null || true
  wait $SERVER_PID 2>/dev/null || true

  # Stop DB server if started
  if [[ -n "$DB_PID" ]]; then
    echo "Stopping DB server..."
    kill $DB_PID 2>/dev/null || true
    wait $DB_PID 2>/dev/null || true
  fi
}
trap cleanup EXIT

HOST="localhost"
PASS_COUNT=0
TOTAL_TESTS=0

### TESTS ###
## TASK 1: Serving Static Contents ##
echo $'\n=== Testing TASK 1: Static Content Serving ==='
# 1. Disallow '/../' 
echo "[TEST] HTTP/1.0 GET /../secret.txt"
TOTAL_TESTS=$((TOTAL_TESTS + 1))
REQUEST=$'GET /../secret.txt HTTP/1.0\r\nHost: localhost\r\nConnection: close\r\n\r\n'
status_line=$(printf "%s" "$REQUEST" \
              | nc -q 1 "$HOST" "$SERVPORT" 2>/dev/null \
              | head -n1 \
              | tr -d '\r')  # remove trailing CR
expected="HTTP/1.0 400 Bad Request"
if [[ "$status_line" == "$expected" ]]; then
    echo -e "RESULT: \033[32;1;4mPASS\033[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "RESULT: \033[31;1;4mFAIL\033[0m"
    echo "Status-line: $status_line"
fi

# 2. Disallow ending with /.. 
echo "[TEST] HTTP/1.0 GET /dir/.."
TOTAL_TESTS=$((TOTAL_TESTS + 1))
REQUEST=$'GET /dir/.. HTTP/1.0\r\nHost: localhost\r\nConnection: close\r\n\r\n'
status_line=$(printf "%s" "$REQUEST" \
              | nc -q 1 "$HOST" "$SERVPORT" 2>/dev/null \
              | head -n1 \
              | tr -d '\r')  # remove trailing CR
expected="HTTP/1.0 400 Bad Request"
if [[ "$status_line" == "$expected" ]]; then
    echo -e "RESULT: \033[32;1;4mPASS\033[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "RESULT: \033[31;1;4mFAIL\033[0m"
    echo "Status-line: $status_line"
fi

# 3. Bad request URL (not starting with /)
echo "[TEST] HTTP/1.0 GET badurl (does not start with /)"
TOTAL_TESTS=$((TOTAL_TESTS + 1))
REQUEST=$'GET badurl.html HTTP/1.0\r\nHost: localhost\r\nConnection: close\r\n\r\n'
status_line=$(printf "%s" "$REQUEST" \
              | nc -q 1 "$HOST" "$SERVPORT" 2>/dev/null \
              | head -n1 \
              | tr -d '\r')  # remove trailing CR
expected="HTTP/1.0 400 Bad Request"
if [[ "$status_line" == "$expected" ]]; then
    echo -e "RESULT: \033[32;1;4mPASS\033[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "RESULT: \033[31;1;4mFAIL\033[0m"
    echo "Status-line: $status_line"
fi

# 4. Bad request URL (file not found)
echo "[TEST] HTTP/1.0 GET /random.html -> 404 Not Found"
TOTAL_TESTS=$((TOTAL_TESTS + 1))
REQUEST=$'GET /random.html HTTP/1.0\r\nHost: localhost\r\nConnection: close\r\n\r\n'
status_line=$(printf "%s" "$REQUEST" \
              | nc -q 1 "$HOST" "$SERVPORT" 2>/dev/null \
              | head -n1 \
              | tr -d '\r')  # remove trailing CR
expected="HTTP/1.0 404 Not Found"
if [[ "$status_line" == "$expected" ]]; then
    echo -e "RESULT: \033[32;1;4mPASS\033[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "RESULT: \033[31;1;4mFAIL\033[0m"
    echo "Status-line: $status_line"
fi

# 5. HTTP/1.0 GET
echo "[TEST] HTTP/1.0 GET /index.html"
TOTAL_TESTS=$((TOTAL_TESTS + 1))
REQUEST=$'GET /index.html HTTP/1.0\r\nHost: localhost\r\nConnection: close\r\n\r\n'
status_line=$(printf "%s" "$REQUEST" \
              | nc -q 1 "$HOST" "$SERVPORT" 2>/dev/null \
              | head -n1 \
              | tr -d '\r')  # remove trailing CR
expected_status="HTTP/1.0 200 OK"
if [[ "$status_line" != "$expected_status" ]]; then
    echo -e "RESULT: \033[31;1;4mFAIL\033[0m"
    echo "Status-line: $status_line"
fi
# Use wget and download the file to verify content
wget -q -O downloaded_index.html "http://$HOST:$SERVPORT/index.html"
if diff -q downloaded_index.html Webpage/index.html; then
    echo -e "RESULT: \033[32;1;4mPASS\033[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "RESULT: \033[31;1;4mFAIL\033[0m"
fi
rm -f downloaded_index.html

# 6. HTTP/1.1 GET
echo "[TEST] HTTP/1.1 GET /index.html"
TOTAL_TESTS=$((TOTAL_TESTS + 1))
REQUEST=$'GET /index.html HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n'
status_line=$(printf "%s" "$REQUEST" \
              | nc -q 1 "$HOST" "$SERVPORT" 2>/dev/null \
              | head -n1 \
              | tr -d '\r')  # remove trailing CR
expected_status="HTTP/1.0 200 OK"
if [[ "$status_line" != "$expected_status" ]]; then
    echo -e "RESULT: \033[31;1;4mFAIL\033[0m"
    echo "Status-line: $status_line"
fi
# Use wget and download the file to verify content
wget -q -O downloaded_index.html "http://$HOST:$SERVPORT/index.html"
if diff -q downloaded_index.html Webpage/index.html; then
    echo -e "RESULT: \033[32;1;4mPASS\033[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "RESULT: \033[31;1;4mFAIL\033[0m"
fi
rm -f downloaded_index.html

# 7. HTTP/1.2 GET (invalid HTTP version)
echo "[TEST] HTTP/1.2 GET /index.html -> 501 Not Implemented"
TOTAL_TESTS=$((TOTAL_TESTS + 1))
REQUEST=$'GET /index.html HTTP/1.2\r\nHost: localhost\r\nConnection: close\r\n\r\n'
RESPONSE=$(printf "%s" "$REQUEST" | nc -q 1 "$HOST" "$SERVPORT" 2>/dev/null)
status_line=$(echo "$RESPONSE" | head -n1 | tr -d '\r')
expected_status="HTTP/1.0 501 Not Implemented"
if [[ "$status_line" != "$expected_status" ]]; then
    echo -e "RESULT: \033[31;1;4mFAIL\033[0m"
    echo "Status-line: $status_line"
fi
# Extract body after the first blank line (\r\n\r\n)
body=$(echo "$RESPONSE" | awk 'BEGIN{RS="\r\n\r\n"} NR==2{print}')
# Compare with expected HTML content
expected_body='<html><body><h1>501 Not Implemented</h1></body></html>'
if [[ "$body" == "$expected_body" ]]; then
    echo -e "RESULT: \033[32;1;4mPASS\033[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "RESULT: \033[31;1;4mFAIL\033[0m"
    echo "Body received: $body"
fi

# 8. HTTP/1.0 POST
echo "[TEST] HTTP/1.0 POST /index.html -> 501 Not Implemented"
TOTAL_TESTS=$((TOTAL_TESTS + 1))
REQUEST=$'POST /index.html HTTP/1.0\r\nHost: localhost\r\nConnection: close\r\n\r\n'
RESPONSE=$(printf "%s" "$REQUEST" | nc -q 1 "$HOST" "$SERVPORT" 2>/dev/null)
status_line=$(echo "$RESPONSE" | head -n1 | tr -d '\r')
expected_status="HTTP/1.0 501 Not Implemented"
if [[ "$status_line" != "$expected_status" ]]; then
    echo -e "RESULT: \033[31;1;4mFAIL\033[0m"
    echo "Status-line: $status_line"
fi
# Extract body after the first blank line (\r\n\r\n)
body=$(echo "$RESPONSE" | awk 'BEGIN{RS="\r\n\r\n"} NR==2{print}')
# Compare with expected HTML content
expected_body='<html><body><h1>501 Not Implemented</h1></body></html>'
if [[ "$body" == "$expected_body" ]]; then
    echo -e "RESULT: \033[32;1;4mPASS\033[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "RESULT: \033[31;1;4mFAIL\033[0m"
    echo "Body received: $body"
fi

# 9. HTTP/1.1 POST
echo "[TEST] HTTP/1.1 POST /index.html -> 501 Not Implemented"
TOTAL_TESTS=$((TOTAL_TESTS + 1))
REQUEST=$'POST /index.html HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n'
RESPONSE=$(printf "%s" "$REQUEST" | nc -q 1 "$HOST" "$SERVPORT" 2>/dev/null)
status_line=$(echo "$RESPONSE" | head -n1 | tr -d '\r')
expected_status="HTTP/1.0 501 Not Implemented"
if [[ "$status_line" != "$expected_status" ]]; then
    echo -e "RESULT: \033[31;1;4mFAIL\033[0m"
    echo "Status-line: $status_line"
fi
# Extract body after the first blank line (\r\n\r\n)
body=$(echo "$RESPONSE" | awk 'BEGIN{RS="\r\n\r\n"} NR==2{print}')
# Compare with expected HTML content
expected_body='<html><body><h1>501 Not Implemented</h1></body></html>'
if [[ "$body" == "$expected_body" ]]; then
    echo -e "RESULT: \033[32;1;4mPASS\033[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "RESULT: \033[31;1;4mFAIL\033[0m"
    echo "Body received: $body"
fi

# 10. Try non-HTTP request
echo "[TEST] Non-HTTP request"
TOTAL_TESTS=$((TOTAL_TESTS + 1))
REQUEST=$'THIS IS NOT A VALID HTTP REQUEST\r\n\r\n'
RESPONSE=$(printf "%s" "$REQUEST" | nc -q 1 "$HOST" "$SERVPORT" 2>/dev/null)
status_line=$(echo "$RESPONSE" | head -n1 | tr -d '\r')
expected="HTTP/1.0 501 Not Implemented"
if [[ "$status_line" == "$expected" ]]; then
    echo -e "RESULT: \033[32;1;4mPASS\033[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "RESULT: \033[31;1;4mFAIL\033[0m"
    echo "Status-line: $status_line"
fi

# 11.   http://localhost:8888/ -> http://localhost:8888/index.html
echo "[TEST] HTTP/1.0 GET /"
TOTAL_TESTS=$((TOTAL_TESTS + 1))
REQUEST=$'GET / HTTP/1.0\r\nHost: localhost\r\nConnection: close\r\n\r\n'
status_line=$(printf "%s" "$REQUEST" \
              | nc -q 1 "$HOST" "$SERVPORT" 2>/dev/null \
              | head -n1 \
              | tr -d '\r')  # remove trailing CR
expected_status="HTTP/1.0 200 OK"
if [[ "$status_line" != "$expected_status" ]]; then
    echo -e "RESULT: \033[31;1;4mFAIL\033[0m"
    echo "Status-line: $status_line"
fi
# Use wget and download the file to verify content
wget -q -O downloaded_index.html "http://$HOST:$SERVPORT/"
if diff -q downloaded_index.html Webpage/index.html; then
    echo -e "RESULT: \033[32;1;4mPASS\033[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "RESULT: \033[31;1;4mFAIL\033[0m"
fi
rm -f downloaded_index.html

# 12. Directory serves index.html
echo "[TEST] HTTP/1.0 GET /Webpage -> serves Webpage/index.html"
TOTAL_TESTS=$((TOTAL_TESTS + 1))
REQUEST=$'GET /Webpage HTTP/1.0\r\nHost: localhost\r\nConnection: close\r\n\r\n'
status_line=$(printf "%s" "$REQUEST" \
              | nc -q 1 "$HOST" "$SERVPORT" 2>/dev/null \
              | head -n1 \
              | tr -d '\r')  # remove trailing CR
expected_status="HTTP/1.0 200 OK"
if [[ "$status_line" != "$expected_status" ]]; then
    echo -e "RESULT: \033[31;1;4mFAIL\033[0m"
    echo "Status-line: $status_line"
else
  # Use wget and download the file to verify content
  wget -q -O downloaded_index.html "http://$HOST:$SERVPORT/Webpage"
  if diff -q downloaded_index.html Webpage/index.html; then
      echo -e "RESULT: \033[32;1;4mPASS\033[0m"
      PASS_COUNT=$((PASS_COUNT + 1))
  else
      echo -e "RESULT: \033[31;1;4mFAIL\033[0m" 
  fi
  rm -f downloaded_index.html
fi

# ---------------------------------------------------------------------------#
## TASK 2: Serving Dynamic Contents ##
echo $'\n=== Testing TASK 2: Dynamic Content Serving ==='

# 13. Test 408 Request Timeout from DB server -> Check by simply not starting DB server
echo "[TEST] HTTP/1.0 GET /db/timeout.txt -> 408 Request Timeout"
TOTAL_TESTS=$((TOTAL_TESTS + 1))
REQUEST=$'GET /?key=cute+cat HTTP/1.0\r\nHost: localhost\r\nConnection: close\r\n\r\n'
status_line=$(printf "%s" "$REQUEST" \
              | nc -q 1 "$HOST" "$SERVPORT" 2>/dev/null \
              | head -n1 \
              | tr -d '\r')  # remove trailing CR
expected="HTTP/1.0 408 Request Timeout"
if [[ "$status_line" == "$expected" ]]; then
    echo -e "RESULT: \033[32;1;4mPASS\033[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "RESULT: \033[31;1;4mFAIL\033[0m"
    echo "Status-line: $status_line"
fi

($DB_CMD > db_server.log 2>&1) &
DB_PID=$!
sleep 1 # give DB server time to start 

# 14. Test File Not Found from DB server
echo "[TEST] HTTP/1.0 GET /?key=really+cute+cat -> 404 Not Found"
TOTAL_TESTS=$((TOTAL_TESTS + 1))
REQUEST=$'GET /?key=really+cute+cat HTTP/1.0\r\nHost: localhost\r\nConnection: close\r\n\r\n'
RESPONSE=$(printf "%s" "$REQUEST" | nc -N "$HOST" "$SERVPORT" 2>/dev/null)
status_line=$(echo "$RESPONSE" | head -n1 | tr -d '\r')
expected="HTTP/1.0 404 Not Found"
if [[ "$status_line" == "$expected" ]]; then
    echo -e "RESULT: \033[32;1;4mPASS\033[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "RESULT: \033[31;1;4mFAIL\033[0m"
    echo "Status-line: $status_line"
fi

# 15. Test valid file from DB server
echo "[TEST] HTTP/1.0 GET /?key=cute+cat"
TOTAL_TESTS=$((TOTAL_TESTS + 1))
# Use curl to fetch the image and save only the body
curl -s "http://$HOST:$SERVPORT/?key=cute+cat" -o downloaded_image.jpg
# Compare downloaded image with expected file
if cmp -s downloaded_image.jpg "cat_database/cute cat.jpg"; then
    echo -e "RESULT: \033[32;1;4mPASS\033[0m"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "RESULT: \033[31;1;4mFAIL\033[0m"
fi

echo $'\n===== Tests complete ====='
echo -e "RESULT: \033[34;1;4m$PASS_COUNT/$TOTAL_TESTS tests passed\033[0m"
echo $'==========================\n'

sleep 5 # give server time to finish logging before cleanup
