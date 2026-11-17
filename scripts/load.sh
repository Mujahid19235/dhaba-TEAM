#!/usr/bin/env bash
set -euo pipefail

URL="${1:-http://staging.TEAM.test}"
DURATION="${2:-30}"
END_TIME=$((SECONDS + DURATION))
SUCCESS=0
FAILED=0

echo "Sending orders to ${URL}/api/orders for ${DURATION}s..."
while [ $SECONDS -lt $END_TIME ]; do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 \
    -X POST "${URL}/api/orders" \
    -H "Content-Type: application/json" \
    -d '{"customer_name":"LoadTester","items":["Biryani"],"total":450}' || echo "000")
  if [ "$CODE" = "201" ] || [ "$CODE" = "200" ]; then
    SUCCESS=$((SUCCESS + 1))
  else
    FAILED=$((FAILED + 1))
  fi
  sleep 0.2
done

echo "Load test finished (${DURATION}s): Succeeded=${SUCCESS}, Failed=${FAILED}"
[ "$FAILED" -eq 0 ]
