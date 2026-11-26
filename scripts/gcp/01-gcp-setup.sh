#!/usr/bin/env bash
# GCP 리소스 생성 (Cloud Shell에서 실행)
# usage: bash scripts/gcp/01-gcp-setup.sh <PROJECT_ID>
set -euo pipefail

PROJECT_ID="${1:?usage: bash 01-gcp-setup.sh <PROJECT_ID>}"
REGION="asia-northeast3"
ZONE="asia-northeast3-a"
VM_NAME="jenkins-server"
CLUSTER_NAME="pillmate-cluster"
SA_NAME="jenkins-gke"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

gcloud config set project "$PROJECT_ID"

echo "[1/5] enable APIs"
gcloud services enable \
  compute.googleapis.com container.googleapis.com \
  servicemanagement.googleapis.com cloudresourcemanager.googleapis.com

echo "[2/5] static IP, firewall(8080, GitHub webhook IP only)"
gcloud compute addresses describe jenkins-ip --region "$REGION" >/dev/null 2>&1 || \
  gcloud compute addresses create jenkins-ip --region "$REGION"
JENKINS_IP=$(gcloud compute addresses describe jenkins-ip --region "$REGION" --format='value(address)')

# 8080은 GitHub webhook 대역만 허용 (https://api.github.com/meta 의 hooks 값)
# 관리 화면은 SSH 터널로 접속, 같은 프로젝트의 다른 VM과 겹치지 않게 전용 태그 사용
GITHUB_HOOK_RANGES="192.30.252.0/22,185.199.108.0/22,140.82.112.0/20,143.55.64.0/20,9.234.106.48/28,9.234.98.160/28,9.234.98.176/28"
gcloud compute firewall-rules describe allow-personal-jenkins-webhook >/dev/null 2>&1 || \
  gcloud compute firewall-rules create allow-personal-jenkins-webhook \
    --allow tcp:8080 --target-tags personal-jenkins --source-ranges "$GITHUB_HOOK_RANGES"

echo "[3/5] jenkins VM"
gcloud compute instances describe "$VM_NAME" --zone "$ZONE" >/dev/null 2>&1 || \
  gcloud compute instances create "$VM_NAME" \
    --zone "$ZONE" --machine-type e2-medium \
    --image-family ubuntu-2204-lts --image-project ubuntu-os-cloud \
    --boot-disk-size 30GB --tags personal-jenkins --address "$JENKINS_IP"

echo "[4/5] GKE cluster"
gcloud container clusters describe "$CLUSTER_NAME" --zone "$ZONE" >/dev/null 2>&1 || \
  gcloud container clusters create "$CLUSTER_NAME" \
    --zone "$ZONE" --num-nodes 1 --machine-type e2-medium --disk-size 30

echo "[5/5] service account + key"
gcloud iam service-accounts describe "$SA_EMAIL" >/dev/null 2>&1 || \
  gcloud iam service-accounts create "$SA_NAME" --display-name "Jenkins GKE deployer"
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member "serviceAccount:${SA_EMAIL}" --role roles/container.developer --condition=None >/dev/null
[ -f jenkins-gke-key.json ] || \
  gcloud iam service-accounts keys create jenkins-gke-key.json --iam-account "$SA_EMAIL"

echo
echo "jenkins : gcloud compute ssh ${VM_NAME} --zone ${ZONE} -- -L 8080:localhost:8080 (터널 후 localhost:8080)"
echo "webhook : http://${JENKINS_IP}:8080/github-webhook/"
echo "key     : $(pwd)/jenkins-gke-key.json"
