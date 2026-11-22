# jdk11 태그는 지원 종료라 jdk21 사용
FROM jenkins/jenkins:lts-jdk21

USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        apt-transport-https ca-certificates curl gnupg build-essential sudo && \
    rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://get.docker.com | sh && usermod -aG docker jenkins

# apt.kubernetes.io가 없어져서 kubectl은 google cloud 저장소에서 설치
RUN curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
        | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
        > /etc/apt/sources.list.d/google-cloud-sdk.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        google-cloud-cli kubectl google-cloud-cli-gke-gcloud-auth-plugin && \
    rm -rf /var/lib/apt/lists/*

USER jenkins

COPY --chown=jenkins:jenkins plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt
