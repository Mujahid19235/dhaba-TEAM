#!/usr/bin/env bash
set -euo pipefail

ISSUES=""
NOT_READY=$(kubectl get nodes --no-headers 2>/dev/null | awk '$2 != "Ready" {print $1":"$2}' | paste -sd "," - || true)
[ -n "$NOT_READY" ] && ISSUES="${ISSUES}Nodes not Ready: ${NOT_READY}; "

BAD_PODS=$(kubectl get pods -A --no-headers 2>/dev/null | awk '$4 ~ /CrashLoopBackOff|ImagePullBackOff|ErrImagePull|Error/ || $5 > 3 {print $1"/"$2"("$4",restarts:"$5")"}' | paste -sd "," - || true)
[ -n "$BAD_PODS" ] && ISSUES="${ISSUES}Unhealthy pods: ${BAD_PODS}; "

WARN_EVENTS=$(kubectl get events -A --field-selector type=Warning --no-headers 2>/dev/null | tail -n 3 | awk '{print $1"/"$2":"$6}' | paste -sd "; " - || true)
if [ -n "$ISSUES" ]; then
  echo "ALERT|cluster|${ISSUES}Recent warnings: ${WARN_EVENTS}"
else
  echo "OK|cluster|All nodes Ready and pods healthy"
fi
