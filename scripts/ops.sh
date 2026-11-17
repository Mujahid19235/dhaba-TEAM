#!/usr/bin/env bash
set -euo pipefail

CMD="${1:-status}"
case "$CMD" in
  status)
    echo "=== NODES ==="
    kubectl get nodes
    echo "=== STAGING ==="
    kubectl -n staging get pods,svc,ingress
    echo "=== PRODUCTION ==="
    kubectl -n production get pods,svc,ingress
    ;;
  db)
    for NS in staging production; do
      echo "=== ${NS} DATABASES ==="
      kubectl -n "$NS" exec statefulset/postgres -- psql -U dhaba -c "SELECT status, COUNT(*) FROM orders GROUP BY status;" 2>/dev/null || echo "Postgres unavailable"
      kubectl -n "$NS" exec statefulset/redis -- redis-cli INFO memory | grep used_memory_human || echo "Redis unavailable"
    done
    ;;
  logs)
    SVC="${2:?Usage: $0 logs <service> [namespace]}"
    NS="${3:-production}"
    kubectl -n "$NS" logs -l "app=${SVC}" --tail=50
    ;;
  load)
    SEC="${2:-15}"
    URL="${3:-http://staging.TEAM.test}"
    "$(dirname "$0")/load.sh" "$URL" "$SEC"
    ;;
  *)
    echo "Usage: $0 {status|db|logs <service> [ns]|load [seconds] [url]}"
    exit 1
    ;;
esac
