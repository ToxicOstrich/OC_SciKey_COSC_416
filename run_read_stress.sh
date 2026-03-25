#!/usr/bin/env bash
DB_USER="your user"
DB_PASS="your password"
DB_CONN="your connection string"

SESSIONS=${1:-4}

echo "Starting read stress test: ${SESSIONS} parallel sessions"
echo "---"

START_TIME=$(date +%s)

for ((i=1; i<=SESSIONS; i++)); do
  sqlplus -s "${DB_USER}/${DB_PASS}@${DB_CONN}" @read_stress_test.sql > "read_stress_session_${i}.log" 2>&1 &
done

wait

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

echo "---"
echo "Read stress test complete."
echo "Sessions: ${SESSIONS}"
echo "Wall clock time: ${ELAPSED}s"
echo ""
echo "Per-session logs: read_stress_session_*.log"
