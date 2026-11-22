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

echo "[2/5] static IP, firewall(8080)"
gcloud compute addresses describe jenkins-ip --region "$REGION" >/dev/null 2>&1 || \
  gcloud compute addresses create jenkins-ip --region "$REGION"
JENKINS_IP=$(gcloud compute addresses describe jenkins-ip --region "$REGION" --format='value(address)')

gcloud compute firewall-rules describe allow-jenkins-8080 >/dev/null 2>&1 || \
  gcloud compute firewall-rules create allow-jenkins-8080 \
    --allow tcp:8080 --target-tags jenkins --source-ranges 0.0.0.0/0

echo "[3/5] jenkins VM"
gcloud compute instances describe "$VM_NAME" --zone "$ZONE" >/dev/null 2>&1 || \
  gcloud compute instances create "$VM_NAME" \
    --zone "$ZONE" --machine-type e2-medium \
    --image-family ubuntu-2204-lts --image-project ubuntu-os-cloud \
    --boot-disk-size 30GB --tags jenkins --address "$JENKINS_IP"

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
echo "jenkins : http://${JENKINS_IP}:8080"
echo "webhook : http://${JENKINS_IP}:8080/github-webhook/"
echo "key     : $(pwd)/jenkins-gke-key.json"
