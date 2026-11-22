#!/usr/bin/env bash
# Jenkins VM에서 실행
# usage: bash 02-jenkins-vm-setup.sh <github-user> [branch]
set -euo pipefail

GH_USER="${1:?usage: bash 02-jenkins-vm-setup.sh <github-user> [branch]}"
BRANCH="${2:-main}"
REPO="https://github.com/${GH_USER}/PillMate-2026.git"

echo "[1/3] docker"
if ! command -v docker >/dev/null; then
  curl -fsSL https://get.docker.com | sudo sh
  sudo usermod -aG docker "$USER"
  sudo systemctl enable --now docker
fi

echo "[2/3] build jenkins image"
rm -rf ~/pillmate-src
git clone --depth 1 -b "$BRANCH" "$REPO" ~/pillmate-src
sudo docker build -t myjenkins ~/pillmate-src/jenkins

echo "[3/3] run jenkins"
sudo docker rm -f myjenkins >/dev/null 2>&1 || true
sudo docker run -d --name myjenkins -p 8080:8080 --restart=always \
  -v jenkins-home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --group-add "$(stat -c '%g' /var/run/docker.sock)" \
  myjenkins

for i in $(seq 1 60); do
  sudo docker exec myjenkins test -f /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null && break
  sleep 3
done

echo
echo "initial admin password:"
sudo docker exec myjenkins cat /var/jenkins_home/secrets/initialAdminPassword
