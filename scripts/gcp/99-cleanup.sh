#!/usr/bin/env bash
# 생성한 GCP 리소스 삭제
# usage: bash scripts/gcp/99-cleanup.sh <PROJECT_ID>
set -euo pipefail
PROJECT_ID="${1:?usage: bash 99-cleanup.sh <PROJECT_ID>}"
REGION="asia-northeast3"; ZONE="asia-northeast3-a"
gcloud config set project "$PROJECT_ID"
read -r -p "delete GKE cluster, jenkins VM, static IP, firewall rule? (yes/no) " ans
[ "$ans" = "yes" ] || exit 0
gcloud container clusters delete pillmate-cluster --zone "$ZONE" --quiet || true
gcloud compute instances delete jenkins-server --zone "$ZONE" --quiet || true
gcloud compute addresses delete jenkins-ip --region "$REGION" --quiet || true
gcloud compute firewall-rules delete allow-jenkins-8080 --quiet || true
