#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOW=$(date +%s)
PREV_STATE=$(kubectl -n ops get configmap monitor-state -o jsonpath='{.data.state}' 2>/dev/null || echo "OK")
LAST_SUMMARY=$(kubectl -n ops get configmap monitor-state -o jsonpath='{.data.last_summary}' 2>/dev/null || echo "0")

RESULTS=$(
  "$DIR/check-cluster.sh"
  "$DIR/check-services.sh"
  "$DIR/check-databases.sh"
)

ALERTS=$(echo "$RESULTS" | grep '^ALERT|' || true)
CURRENT_STATE="OK"
[ -n "$ALERTS" ] && CURRENT_STATE="ALERT"

post_slack() {
  local MSG="$1"
  if [ -n "${SLACK_WEBHOOK_URL:-}" ]; then
    curl -s -X POST -H 'Content-type: application/json' \
      --data "{\"text\":\"${MSG}\"}" "$SLACK_WEBHOOK_URL" >/dev/null
  fi
  echo "$MSG"
}

if [ "$CURRENT_STATE" = "ALERT" ] && [ "$PREV_STATE" != "ALERT" ]; then
  post_slack "[MONITOR ALERT] ${ALERTS//$'\n'/ | }"
elif [ "$CURRENT_STATE" = "OK" ] && [ "$PREV_STATE" = "ALERT" ]; then
  post_slack "[MONITOR RECOVERED] All cluster, service, and database checks are back to normal."
elif [ "$CURRENT_STATE" = "OK" ] && [ $((NOW - LAST_SUMMARY)) -ge 1800 ]; then
  post_slack "[MONITOR SUMMARY] All well across cluster, staging, and production."
  LAST_SUMMARY="$NOW"
fi

kubectl -n ops create configmap monitor-state \
  --from-literal=state="$CURRENT_STATE" \
  --from-literal=last_summary="$LAST_SUMMARY" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null
