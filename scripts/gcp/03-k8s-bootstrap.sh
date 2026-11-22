#!/usr/bin/env bash
# 클러스터 초기 설정: secret, DB 초기화 sql, mysql 배포 (최초 1회)
# usage: bash scripts/gcp/03-k8s-bootstrap.sh <PROJECT_ID> <env-file> [gcp-key.json]
# env-file은 .env.example 기준 + DB_ROOT_PASSWORD 추가
set -euo pipefail

PROJECT_ID="${1:?usage: bash 03-k8s-bootstrap.sh <PROJECT_ID> <env-file> [gcp-key.json]}"
ENV_FILE="${2:?env file required}"
GCP_KEY="${3:-}"
ZONE="asia-northeast3-a"
CLUSTER_NAME="pillmate-cluster"

grep -q '^DB_ROOT_PASSWORD=.\+' "$ENV_FILE" || { echo "DB_ROOT_PASSWORD missing in $ENV_FILE"; exit 1; }
grep -q '^GOOGLE_CLIENT_ID=.\+' "$ENV_FILE" || { echo "GOOGLE_CLIENT_ID is empty (app won't start)"; exit 1; }

gcloud container clusters get-credentials "$CLUSTER_NAME" --zone "$ZONE" --project "$PROJECT_ID"

kubectl create secret generic pillmate-env --from-env-file="$ENV_FILE" \
  --dry-run=client -o yaml | kubectl apply -f -

if [ -n "$GCP_KEY" ]; then
  kubectl create secret generic pillmate-gcp-key --from-file=gcp-key.json="$GCP_KEY" \
    --dry-run=client -o yaml | kubectl apply -f -
else
  kubectl create secret generic pillmate-gcp-key --from-literal=gcp-key.json='{}' \
    --dry-run=client -o yaml | kubectl apply -f -
fi

# seed 파일이 커서 apply 하면 annotation 크기 제한(256KB)에 걸림 -> delete 후 create
kubectl delete configmap pillmate-db-init --ignore-not-found
kubectl create configmap pillmate-db-init \
  --from-file=01-schema.sql=db/schema.sql \
  --from-file=02-seed_waste_bins.sql=db/seed_waste_bins.sql \
  --from-file=03-seed_chatbot.sql=db/seed_chatbot.sql

kubectl apply -f k8s/mysql.yaml
kubectl rollout status deployment/pillmate-mysql --timeout=300s
