#!/usr/bin/env bash
set -euo pipefail

ISSUES=""
for NS in staging production; do
  if ! kubectl -n "$NS" exec statefulset/postgres -- pg_isready -U dhaba >/dev/null 2>&1; then
    ISSUES="${ISSUES}${NS}/postgres unreachable; "
  fi
  if ! kubectl -n "$NS" exec statefulset/redis -- redis-cli ping 2>/dev/null | grep -q PONG; then
    ISSUES="${ISSUES}${NS}/redis unreachable; "
  fi
done

if [ -n "$ISSUES" ]; then
  echo "ALERT|databases|${ISSUES}"
else
  echo "OK|databases|Postgres and Redis healthy in staging & production"
fi
