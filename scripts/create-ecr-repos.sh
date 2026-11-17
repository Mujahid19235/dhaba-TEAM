#!/usr/bin/env bash
set -euo pipefail

TEAM="${1:-${TEAM:-}}"
AWS_REGION="${2:-${AWS_REGION:-}}"

if [[ -z "$TEAM" || -z "$AWS_REGION" ]]; then
  echo "Usage: TEAM=<team-name> AWS_REGION=<region> $0"
  echo "   or: $0 <team-name> <aws-region>"
  exit 1
fi

SERVICES=(
  "web"
  "menu-api"
  "orders-api"
  "kitchen-worker"
  "stats-api"
  "postgres"
  "redis"
  "ops-monitor"
)

LIFECYCLE_POLICY='{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Keep only the newest 20 images",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 20
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}'

for svc in "${SERVICES[@]}"; do
  REPO_NAME="dhaba-${TEAM}/${svc}"
  if aws ecr describe-repositories --repository-names "$REPO_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
    echo "[OK] Repository already exists: ${REPO_NAME}"
  else
    echo "[CREATE] Creating repository: ${REPO_NAME}"
    aws ecr create-repository \
      --repository-name "$REPO_NAME" \
      --region "$AWS_REGION" \
      --image-scanning-configuration scanOnPush=true \
      --output text >/dev/null
    echo "[CREATED] ${REPO_NAME}"
  fi

  aws ecr put-lifecycle-policy \
    --repository-name "$REPO_NAME" \
    --region "$AWS_REGION" \
    --lifecycle-policy-text "$LIFECYCLE_POLICY" \
    --output text >/dev/null
done

echo "All 8 ECR repositories verified in ${AWS_REGION}."
