#!/usr/bin/env bash
set -euo pipefail

ISSUES=""
for NS in staging production; do
  if ! kubectl -n "$NS" exec deploy/orders-api -- /app/orders-api -healthcheck >/dev/null 2>&1; then
    ISSUES="${ISSUES}${NS}/orders-api healthcheck failed; "
  fi
  QLEN=$(kubectl -n "$NS" exec statefulset/redis -- redis-cli LLEN orders_queue 2>/dev/null || echo "-1")
  if [ "$QLEN" -gt 50 ] 2>/dev/null; then
    ISSUES="${ISSUES}${NS} queue backlog high (${QLEN}); "
  fi
done

if [ -n "$ISSUES" ]; then
  echo "ALERT|services|${ISSUES}"
else
  echo "OK|services|All service healthchecks and queues normal"
fi
